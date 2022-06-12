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
  /var/lib/$SERVICE/instances \
  /var/log/$SERVICE \
  /run/uwsgi/$SERVICE

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

DATABASES=($SERVICE $SERVICE"_api" $SERVICE"_cell0")
for DATABASE in "${DATABASES[@]}"
do
  echo "SELECT 'CREATE DATABASE \"$DATABASE\"' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DATABASE')\gexec" | sudo -u postgres psql -q
done
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
for DATABASE in "${DATABASES[@]}"
do
  sudo -u postgres psql -q -c "GRANT ALL PRIVILEGES ON DATABASE \"$DATABASE\" TO $SERVICE;"
done

sudo chown -R $SERVICE:$SERVICE /etc/$SERVICE
sudo chown -R $SERVICE:$SERVICE /var/lib/$SERVICE
sudo chown -R $SERVICE:$SERVICE /var/log/$SERVICE

HOST=$(hostname -f)
SERVICE_PASSPHRASE=$NOVA_PASSPHRASE
. ~/.openrc-admin
openstack user create --domain default $SERVICE --password=$SERVICE_PASSPHRASE
openstack role add --project service --user $SERVICE admin

openstack service create --name $SERVICE --description "$DESCRIPTION" $SERVICE_TYPE
openstack endpoint create --region $REGION $SERVICE_TYPE public https://$HOST:$SERVICE_PORT/v2.1
openstack endpoint create --region $REGION $SERVICE_TYPE internal https://$HOST:$SERVICE_PORT/v2.1
openstack endpoint create --region $REGION $SERVICE_TYPE admin https://$HOST:$SERVICE_PORT/v2.1

RABBIT_OPENSTACK_PASSPHRASE=$RABBIT_PASSPHRASE
sudo rabbitmqctl add_user openstack $RABBIT_OPENSTACK_PASSPHRASE
sudo rabbitmqctl set_user_tags openstack administrator
sudo rabbitmqctl set_permissions -p / openstack ".*" ".*" ".*"

sudo -u $SERVICE \
  SERVICE=$SERVICE \
  SERVICE_PORT=$SERVICE_PORT \
  SERVICE_PASSPHRASE=$SERVICE_PASSPHRASE \
  KEYSTONE_HOST=$KEYSTONE_HOST \
  KEYSTONE_PORT=$KEYSTONE_PORT \
  MEMCACHE_PORT=$MEMCACHE_PORT \
  NEUTRON_PASSPHRASE=$NEUTRON_PASSPHRASE \
  METADATA_SECRET=$METADATA_SECRET \
  RABBIT_HOST=$RABBIT_HOST \
  RABBIT_PORT=$RABBIT_PORT \
  RABBIT_OPENSTACK_PASSPHRASE=$RABBIT_OPENSTACK_PASSPHRASE \
  REGION=$REGION \
  PLACEMENT_PASSPHRASE=$PLACEMENT_PASSPHRASE \
  REBUILD=$REBUILD \
  DEBUG=$DEBUG \
  ~/install/scripts/openstack/yoga/install-compute-service.sh

unset SERVICE_PASSPHRASE

# prepare for uwsgi and nginx configuration

sudo usermod -G $SERVICE,www-data,libvirt $SERVICE

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
  # this is insecure
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

sudo bash -c "cat > /lib/systemd/system/nova-scheduler.service" << EOF
[Unit]
Description=Openstack Compute Controller Scheduler
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/nova/venv/bin/nova-scheduler
User=nova
Group=nova
WorkingDirectory=/var/lib/nova

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > /lib/systemd/system/nova-conductor.service" << EOF
[Unit]
Description=Openstack Compute Controller Conductor
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/nova/venv/bin/nova-conductor
User=nova
Group=nova
WorkingDirectory=/var/lib/nova

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart nova-scheduler nova-conductor
sudo systemctl enable nova-scheduler nova-conductor
