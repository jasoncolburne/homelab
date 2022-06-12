#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo ~/install/scripts/openstack/yoga/dependencies/common.sh
[[ -f ~/install/scripts/openstack/yoga/dependencies/$SERVICE.sh ]] && sudo ~/install/scripts/openstack/yoga/dependencies/$SERVICE.sh

sudo mkdir -p \
  /etc/$SERVICE \
  /var/lib/$SERVICE/venv \
  /var/lib/$SERVICE/src \
  /var/lib/$SERVICE/patch \
  /var/log/$SERVICE \
  /run/uwsgi/$SERVICE

mkdir -p ~/src/openstack

cd ~/src/openstack
[[ -d $SERVICE ]] || git clone https://opendev.org/openstack/$SERVICE.git -b stable/yoga

[[ $REBUILD == "1" ]] && sudo rm -rf /var/lib/$SERVICE/src/$SERVICE
sudo cp -R ~/src/openstack/$SERVICE /var/lib/$SERVICE/src
sudo cp ~/install/patch/$SERVICE*.conf.patch /var/lib/$SERVICE/patch || true
sudo cp ~/install/patch/metadata_agent.ini.patch /var/lib/$SERVICE/patch || true

# this is actually flawed but we won't see a problem
if rg -qF $SERVICE /etc/passwd
then
  echo "skipping user $SERVICE creation"
else
  sudo useradd \
    --home-dir "/var/lib/$SERVICE" \
    --create-home \
    --system \
    --shell /bin/false \
    $SERVICE
fi

echo "SELECT 'CREATE DATABASE $SERVICE' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$SERVICE')\gexec" | sudo -u postgres psql -q
sudo -u postgres psql -q << PLPGSQL
DO
\$do\$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_roles
    WHERE  rolname = '$SERVICE') THEN

    CREATE ROLE $SERVICE LOGIN;
  END IF;
END
\$do\$;
PLPGSQL
sudo -u postgres psql -q -c "GRANT ALL PRIVILEGES ON DATABASE $SERVICE TO $SERVICE;"

sudo chown -R $SERVICE:$SERVICE /etc/$SERVICE
sudo chown -R $SERVICE:$SERVICE /var/lib/$SERVICE
sudo chown -R $SERVICE:$SERVICE /var/log/$SERVICE

HOST=$(hostname -f)
SERVICE_PASSPHRASE=$NEUTRON_PASSPHRASE

. ~/.openrc-admin
openstack user create --domain default $SERVICE --password=$SERVICE_PASSPHRASE
openstack role add --project service --user $SERVICE admin
openstack service create --name $SERVICE --description "$DESCRIPTION" $SERVICE_TYPE
openstack endpoint create --region $REGION $SERVICE_TYPE public https://$HOST:$SERVICE_PORT
openstack endpoint create --region $REGION $SERVICE_TYPE internal https://$HOST:$SERVICE_PORT
openstack endpoint create --region $REGION $SERVICE_TYPE admin https://$HOST:$SERVICE_PORT

sudo -u $SERVICE \
  SERVICE=$SERVICE \
  SERVICE_PORT=$SERVICE_PORT \
  SERVICE_PASSPHRASE=$SERVICE_PASSPHRASE \
  KEYSTONE_HOST=$KEYSTONE_HOST \
  KEYSTONE_PORT=$KEYSTONE_PORT \
  MEMCACHE_PORT=$MEMCACHE_PORT \
  RABBIT_HOST=$RABBIT_HOST \
  RABBIT_PORT=$RABBIT_PORT \
  RABBIT_OPENSTACK_PASSPHRASE=$RABBIT_PASSPHRASE \
  REGION=$REGION \
  NOVA_PASSPHRASE=$NOVA_PASSPHRASE \
  METADATA_HOST=$METADATA_HOST \
  METADATA_SECRET=$METADATA_SECRET \
  PUBLIC_NETWORK_INTERFACE=$PUBLIC_NETWORK_INTERFACE \
  REBUILD=$REBUILD \
  DEBUG=$DEBUG \
  ~/install/scripts/openstack/yoga/install-network-service.sh

unset SERVICE_PASSPHRASE

# prepare for uwsgi and nginx configuration

sudo usermod -G $SERVICE,www-data $SERVICE

sudo systemctl stop nginx
sudo rm -f /etc/nginx/sites-enabled/default

sudo mkdir /var/log/nginx/$SERVICE
sudo chown www-data:www-data /var/log/nginx/$SERVICE
sudo mkdir /var/www/$SERVICE

# uwsgi

sudo bash -c "cat > /etc/uwsgi/apps-available/$SERVICE.ini" << EOF
[uwsgi]
env = REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
master = true
plugin = python3
thunder-lock = true
processes = 3  
threads = 2  
chmod-socket = 660
chown-socket = $SERVICE:www-data

name = $SERVICE
uid = $SERVICE
gid = www-data

chdir = /var/www/$SERVICE/
virtualenv = /var/lib/$SERVICE/venv
wsgi-file = /var/lib/$SERVICE/venv/bin/$WSGI_SCRIPT

no-orphans = true
vacuum = true
EOF

sudo ln -s /etc/uwsgi/apps-{available,enabled}/$SERVICE.ini

sudo systemctl restart uwsgi

# nginx

sudo bash -c "cat > /etc/nginx/sites-available/$SERVICE.conf" << EOF
server {
    listen      $SERVICE_PORT ssl;
    access_log  /var/log/nginx/$SERVICE/access.log;
    error_log   /var/log/nginx/$SERVICE/error.log;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
    ssl_ecdh_curve secp384r1;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    client_max_body_size 4G;

    location / {
        uwsgi_pass    unix:///run/uwsgi/app/$SERVICE/socket;
        include       uwsgi_params;
        uwsgi_param   SCRIPT_NAME '';
    }
}
EOF

sudo ln -s /etc/nginx/sites-{available,enabled}/$SERVICE.conf
sudo sed -i "s/worker_processes auto/worker_processes 6/" /etc/nginx/nginx.conf

[[ ! -f /etc/ssl/certs/dhparam.pem ]] && sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
if [[ ! -f /usr/local/bin/mkcert ]]
then
  sudo apt-get -y install libnss3-tools
  curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
  chmod +x mkcert-v*-linux-amd64
  sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
  sudo mkcert --install
fi

if [[ ! -d /etc/nginx/ssl ]]
then
  sudo mkdir -p /etc/nginx/ssl
  sudo mkcert -ecdsa $HOST
  sudo mv $HOST.pem /etc/nginx/ssl/cert.pem
  sudo mv $HOST-key.pem /etc/nginx/ssl/key.pem
fi

sudo systemctl restart nginx

# set up scheduler and conductor as services

sudo bash -c "cat > /etc/$SERVICE/rootwrap.d/rootwrap.filters" << EOF
# Command filters to allow privsep daemon to be started via rootwrap.
#
# This file should be owned by (and only-writeable by) the root user

[Filters]

# By installing the following, the local admin is asserting that:
#
# 1. The python module load path used by privsep-helper
#    command as root (as started by sudo/rootwrap) is trusted.
# 2. Any oslo.config files matching the --config-file
#    arguments below are trusted.
# 3. Users allowed to run sudo/rootwrap with this configuration(*) are
#    also allowed to invoke python "entrypoint" functions from
#    --privsep_context with the additional (possibly root) privileges
#    configured for that context.
#
# (*) ie: the user is allowed by /etc/sudoers to run rootwrap as root
#
# In particular, the oslo.config and python module path must not
# be writeable by the unprivileged user.

# PRIVSEP
# oslo.privsep default neutron context
privsep: RegExpFilter, /var/lib/neutron/venv/bin/privsep-helper, root, /var/lib/neutron/venv/bin/privsep-helper,
 --privsep_context, neutron\.privileged\.default,
 --privsep_sock_path, /tmp/(?!\.\.).*

#privsep: RegExpFilter, /var/lib/neutron/venv/bin/privsep-helper, root, /var/lib/neutron/venv/bin/privsep-helper,
# --config-file, /etc/(?!\.\.).*,
# --config-file, /etc/(?!\.\.).*,
# --privsep_context, neutron\.privileged\.default,
# --privsep_sock_path, /tmp/(?!\.\.).*

# NOTE: A second `--config-file` arg can also be added above. Since
# many neutron components are installed like that (eg: by devstack).
# Adjust to suit local requirements.

# DEBUG
sleep: RegExpFilter, sleep, root, sleep, \d+

# EXECUTE COMMANDS IN A NAMESPACE
ip: IpFilter, ip, root
ip_exec: IpNetnsExecFilter, ip, root

# METADATA PROXY
haproxy: RegExpFilter, haproxy, root, haproxy, -f, .*

# DHCP
dnsmasq: CommandFilter, dnsmasq, root

# DIBBLER
dibbler-client: CommandFilter, dibbler-client, root

# L3
radvd: CommandFilter, radvd, root
keepalived: CommandFilter, keepalived, root
keepalived_state_change: CommandFilter, neutron-keepalived-state-change, root

# OPEN VSWITCH
ovs-ofctl: CommandFilter, ovs-ofctl, root
ovsdb-client: CommandFilter, ovsdb-client, root
EOF

sudo bash -c "cat > /etc/$SERVICE/rootwrap.conf" << EOF
# Configuration for neutron-rootwrap
# This file should be owned by (and only-writeable by) the root user

[DEFAULT]
# List of directories to load filter definitions from (separated by ',').
# These directories MUST all be only writeable by root !
filters_path=/etc/neutron/rootwrap.d,/usr/share/neutron/rootwrap

# List of directories to search executables in, in case filters do not
# explicitely specify a full path (separated by ',')
# If not specified, defaults to system PATH environment variable.
# These directories MUST all be only writeable by root !
exec_dirs=/sbin,/usr/sbin,/bin,/usr/bin,/usr/local/bin,/usr/local/sbin,/etc/neutron/kill_scripts,/var/lib/neutron/venv/bin

# Enable logging to syslog
# Default value is False
use_syslog=True

# Which syslog facility to use.
# Valid values include auth, authpriv, syslog, local0, local1...
# Default value is 'syslog'
syslog_log_facility=syslog

# Which messages to log.
# INFO means log all usage
# ERROR means only log unsuccessful attempts
syslog_log_level=ERROR

# Rootwrap daemon exits after this seconds of inactivity
daemon_timeout=600

# Rootwrap daemon limits itself to that many file descriptors (Linux only)
rlimit_nofile=1024
EOF

sudo bash -c "cat > /lib/systemd/system/neutron-linuxbridge-agent.service" << EOF
[Unit]
Description=Openstack Network LinuxBridge Agent
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/neutron/venv/bin/neutron-linuxbridge-agent --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini --config-file /etc/neutron/plugins/ml2/linuxbridge_agent.ini
User=neutron
Group=neutron
WorkingDirectory=/var/lib/neutron

[Install]
WantedBy=multi-user.target
EOF

# 2022-06-07 17:55:56.337 [debug] <0.4120.1> Supervisor {<0.4120.1>,rabbit_channel_sup} started rabbit_channel:start_link(1, <0.4115.1>, <0.4121.1>, <0.4115.1>, <<"127.0.0.1:38606 -> 127.0.1.1:5672">>, rabbit_framing_amqp_0_9_1, {user,<<"openstack">>,[administrator],[{rabbit_auth_backend_internal,none}]}, <<"/">>, [{<<"authentication_failure_close">>,bool,true},{<<"connection.blocked">>,bool,true},{<<"consumer...">>,...}], <0.4116.1>, <0.4122.1>) at pid <0.4123.1>

sudo bash -c "cat > /lib/systemd/system/neutron-dhcp-agent.service" << EOF
[Unit]
Description=Openstack Network DHCP Agent
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/neutron/venv/bin/neutron-dhcp-agent
User=neutron
Group=neutron
WorkingDirectory=/var/lib/neutron

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > /lib/systemd/system/neutron-metadata-agent.service" << EOF
[Unit]
Description=Openstack Network Metadata Agent
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/neutron/venv/bin/neutron-metadata-agent
User=neutron
Group=neutron
WorkingDirectory=/var/lib/neutron

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > /lib/systemd/system/neutron-l3-agent.service" << EOF
[Unit]
Description=Openstack Network L3 Agent
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/neutron/venv/bin/neutron-l3-agent
User=neutron
Group=neutron
WorkingDirectory=/var/lib/neutron

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
sudo systemctl enable neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
