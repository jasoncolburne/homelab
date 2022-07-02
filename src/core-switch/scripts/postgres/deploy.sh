#!/usr/bin/bash
# https://www.rabbitmq.com/install-debian.html

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install postgresql

sudo systemctl stop postgresql
sudo systemctl disable postgresql

sudo tee /lib/systemd/system/postgresql@.service << EOF
# systemd service template for PostgreSQL clusters. The actual instances will
# be called "postgresql@version-cluster", e.g. "postgresql@9.3-main". The
# variable %i expands to "version-cluster", %I expands to "version/cluster".
# (%I breaks for cluster names containing dashes.)

[Unit]
Description=PostgreSQL Cluster %i
AssertPathExists=/etc/postgresql/%I/postgresql.conf
RequiresMountsFor=/etc/postgresql/%I /var/lib/postgresql/%I
PartOf=postgresql.service
ReloadPropagatedFrom=postgresql.service
Before=postgresql.service
# stop server before networking goes down on shutdown
After=network.target

[Service]
NetworkNamespacePath=/run/netns/pgsql
Type=forking
# -: ignore startup failure (recovery might take arbitrarily long)
# the actual pg_ctl timeout is configured in pg_ctl.conf
ExecStart=-/usr/bin/pg_ctlcluster --skip-systemctl-redirect %i start
# 0 is the same as infinity, but "infinity" needs systemd 229
TimeoutStartSec=0
ExecStop=/usr/bin/pg_ctlcluster --skip-systemctl-redirect -m fast %i stop
TimeoutStopSec=1h
ExecReload=/usr/bin/pg_ctlcluster --skip-systemctl-redirect %i reload
PIDFile=/run/postgresql/%i.pid
SyslogIdentifier=postgresql@%i
# prevent OOM killer from choosing the postmaster (individual backends will
# reset the score to 0)
OOMScoreAdjust=-900
# restarting automatically will prevent "pg_ctlcluster ... stop" from working,
# so we disable it here. Also, the postmaster will restart by itself on most
# problems anyway, so it is questionable if one wants to enable external
# automatic restarts.
#Restart=on-failure
# (This should make pg_ctlcluster stop work, but doesn't:)
#RestartPreventExitStatus=SIGINT SIGTERM

[Install]
WantedBy=multi-user.target
EOF

sudo mkcert -ecdsa pgsql-infr
sudo chown postgres:postgres pgsql-infr*
sudo mv pgsql-infr* /etc/postgresql/13/main
sudo sed -i "s/^#\?listen_addresses = .*$/listen_addresses = pgsql-infr/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?password_encryption = .*$/password_encryption = scram-sha-256/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_cert_file = .*$/ssl_cert_file = '\/etc\/postgresql\/13\/main\/pgsql-infr.pem'/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_key_file = .*$/ssl_key_file = '\/etc\/postgresql\/13\/main\/pgsql-infr-key.pem'/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_ciphers = .*$/ssl_ciphers = 'HIGH:\!aNULL'/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_prefer_server_ciphers = .*$/ssl_prefer_server_ciphers = on/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_ecdh_curve = .*$/ssl_ecdh_curve = 'prime256v1'/" /etc/postgresql/13/main/postgresql.conf
sudo sed -i "s/^#\?ssl_min_protocol_version = .*$/ssl_min_protocol_version = 'TLSv1.3'/" /etc/postgresql/13/main/postgresql.conf


#ssl_crl_file = ''
#ssl_min_protocol_version = 'TLSv1.2'
#ssl_max_protocol_version = ''
#ssl_dh_params_file = ''
#ssl_passphrase_command = ''
#ssl_passphrase_command_supports_reload = off

sudo systemctl daemon-reload
