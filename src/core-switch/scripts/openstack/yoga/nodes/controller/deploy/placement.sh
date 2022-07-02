#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

NODE_API_IP_ADDRESS=$(rg os-ctrl-api /etc/hosts | cut -d " " -f1)
NODE_INFR_IP_ADDRESS=$(rg os-ctrl-infr /etc/hosts | cut -d " " -f1)

CONTROLLER_DIR=~/install/scripts/openstack/yoga/nodes/controller
DEPENDENCY_DIR=${CONTROLLER_DIR}/dependencies
sudo ${DEPENDENCY_DIR}/common.sh
sudo ${DEPENDENCY_DIR}/placement.sh

sudo mkdir -p \
  /etc/$SERVICE \
  /var/lib/$SERVICE/venv \
  /var/lib/$SERVICE/src \
  /var/lib/$SERVICE/patch

mkdir -p ~/src/openstack

cd ~/src/openstack
[[ -d $SERVICE ]] || git clone https://opendev.org/openstack/$SERVICE.git -b stable/yoga

[[ $REBUILD == "1" ]] && sudo rm -rf /var/lib/$SERVICE/src/$SERVICE
sudo cp -R ~/src/openstack/$SERVICE /var/lib/$SERVICE/src
sudo cp ~/install/patch/$SERVICE*.conf.patch /var/lib/$SERVICE/patch || true

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

POSTGRES_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
echo "SELECT 'CREATE DATABASE $SERVICE' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$SERVICE')\gexec" | sudo -u postgres psql -q
sudo -u postgres psql -q << PLPGSQL
DO
\$do\$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_roles
    WHERE  rolname = '$SERVICE') THEN

    CREATE ROLE $SERVICE LOGIN PASSWORD '${POSTGRES_PASSPHRASE}';
  END IF;
END
\$do\$;
PLPGSQL
sudo -u postgres psql -q -c "GRANT ALL PRIVILEGES ON DATABASE $SERVICE TO $SERVICE;"

if sudo rg "hostssl.+${SERVICE}" /etc/postgresql/13/main/ph_hba.conf
then
  sudo sed -i "s/^hostssl.+${SERVICE}.+$/hostssl ${SERVICE} ${SERVICE} ${NODE_INFR_IP_ADDRESS}\/32 scram-sha-256/" /etc/postgresql/13/main/pg_hba.conf
else
  echo "hostssl ${SERVICE} ${SERVICE} ${NODE_INFR_IP_ADDRESS}/32 scram-sha-256" | sudo tee -a /etc/postgresql/13/main/pg_hba.conf
fi

sudo systemctl restart postgresql

sudo chown -R $SERVICE:$SERVICE /etc/$SERVICE
sudo chown -R $SERVICE:$SERVICE /var/lib/$SERVICE

HOST=$(hostname -f)
if [[ "$SERVICE" == "placement" ]]
then
  SERVICE_PASSPHRASE=$PLACEMENT_PASSPHRASE
else
  SERVICE_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
fi
source ~/.openrc-admin
openstack user create --domain default $SERVICE --password=$SERVICE_PASSPHRASE
openstack role add --project service --user $SERVICE admin
openstack service create --name $SERVICE --description "$DESCRIPTION" $SERVICE_TYPE
openstack endpoint create --region $REGION $SERVICE_TYPE public https://$HOST:$SERVICE_PORT
openstack endpoint create --region $REGION $SERVICE_TYPE internal https://$HOST:$SERVICE_PORT
openstack endpoint create --region $REGION $SERVICE_TYPE admin https://$HOST:$SERVICE_PORT

sudo ip netns exec os-ctrl \
sudo -u $SERVICE \
  SERVICE=$SERVICE \
  SERVICE_PORT=$SERVICE_PORT \
  SERVICE_PASSPHRASE=$SERVICE_PASSPHRASE \
  POSTGRES_PASSPHRASE=$POSTGRES_PASSPHRASE \
  KEYSTONE_HOST=$KEYSTONE_HOST \
  KEYSTONE_PORT=$KEYSTONE_PORT \
  MEMCACHE_PORT=$MEMCACHE_PORT \
  REBUILD=$REBUILD \
  ~/install/scripts/openstack/yoga/nodes/controller/install/placement.sh

unset SERVICE_PASSPHRASE
unset POSTGRES_PASSPHRASE

# prepare for uwsgi and nginx configuration

sudo usermod -G $SERVICE,www-data $SERVICE

sudo systemctl stop nginx-ctrl

sudo mkdir /var/log/nginx/$SERVICE
sudo chown www-data:www-data /var/log/nginx/$SERVICE
sudo mkdir /var/www/$SERVICE

# port forwarder
HOST_IP_ADDRESS=$(rg core\\.homelab /etc/hosts | cut -d " " -f1)
sudo tee /lib/systemd/system/os-fwd-${SERVICE}.service << EOF
[Unit]
Description=${SERVICE} API forwarder
After=network-online.target
Requires=nginx-ctrl.service
After=nginx-ctrl.service

[Service]
Type=simple

ExecStart=/usr/bin/socat tcp4-listen:${SERVICE_PORT},fork,reuseaddr,bind=${HOST_IP_ADDRESS} tcp4:os-ctrl-api:${SERVICE_PORT}
User=${SERVICE}
Group=${SERVICE}
SyslogIdentifier=os-fwd-${SERVICE}
SuccessExitStatus=143

Restart=on-failure

# Time to wait before forcefully stopped.
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

# uwsgi
sudo tee /lib/systemd/system/uwsgi-${SERVICE}.service << EOF
[Unit]
Description=${SERVICE} uWSGI server
After=postgresql.service
Wants=postgresql.service

[Service]
Type=simple
NetworkNamespacePath=/run/netns/os-ctrl
Restart=on-failure
Environment='UWSGI_DEB_CONFNAME=${SERVICE}' 'UWSGI_DEB_CONFNAMESPACE=app'
ExecStartPre=mkdir -p /run/uwsgi/app/${SERVICE}; chown ${SERVICE}:www-data /run/uwsgi/app/${SERVICE}
ExecStart=/usr/bin/uwsgi --ini /usr/share/uwsgi/conf/default.ini --ini /etc/uwsgi/apps-enabled/${SERVICE}.ini
ExecStopPost=rm -rf /run/uwsgi/app/${SERVICE}
KillSignal=SIGQUIT
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

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

sudo systemctl daemon-reload
sudo systemctl restart uwsgi-${SERVICE}

# nginx

sudo bash -c "cat > /etc/nginx/ctrl/sites-available/$SERVICE.conf" << EOF
server {
    listen      ${NODE_API_IP_ADDRESS}:$SERVICE_PORT ssl;
    access_log  /var/log/nginx/$SERVICE/access.log;
    error_log   /var/log/nginx/$SERVICE/error.log;

    ssl_certificate     /etc/nginx/ssl/core.homelab.pem;
    ssl_certificate_key /etc/nginx/ssl/core.homelab-key.pem;

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

    location / {
        uwsgi_pass    unix:///run/uwsgi/app/$SERVICE/socket;
        include       uwsgi_params;
        uwsgi_param   SCRIPT_NAME '';
    }
}
EOF

sudo ln -s /etc/nginx/ctrl/sites-{available,enabled}/$SERVICE.conf

sudo systemctl restart nginx-ctrl
for FORWARDER_PATH in /lib/systemd/system/os-fwd-*
do
  sudo systemctl restart $(basename $FORWARDER_PATH)
done
