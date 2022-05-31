#!/usr/bin/bash

set -euxo pipefail

OLD_PWD=$(pwd)

sudo ~/install/scripts/install-dependencies/$SERVICE.sh

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

sudo rm -rf /var/lib/$SERVICE/src/$SERVICE
sudo cp -R ~/src/openstack/$SERVICE /var/lib/$SERVICE/src
sudo cp -R ~/install/patch/$SERVICE* /var/lib/$SERVICE/patch

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

if [[ $SERVICE_ADMIN_PORT != disabled ]]
then
  HOST=$(hostname)
  SERVICE_ADMIN_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64)
  cat > ~/.openrc-admin << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$SERVICE_ADMIN_PASSPHRASE
export OS_AUTH_URL=http://$HOST:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
else
  # gross
  SERVICE_ADMIN_PASSPHRASE=
fi

sudo -u $SERVICE SERVICE=$SERVICE SERVICE_PORT=$SERVICE_PORT SERVICE_ADMIN_PASSPHRASE=$SERVICE_ADMIN_PASSPHRASE ~/install/scripts/install-openstack-yoga-service.sh

# prepare for uwsgi and nginx configuration

sudo usermod -G www-data $SERVICE

sudo systemctl stop nginx
sudo rm -f /etc/nginx/sites-enabled/default

sudo mkdir /var/log/nginx/$SERVICE
sudo chown www-data:www-data /var/log/nginx/$SERVICE
sudo mkdir /var/www/$SERVICE

# uwsgi

if [[ $SERVICE_ADMIN_PORT != disabled ]]
then
  sudo bash -c "cat > /etc/uwsgi/apps-available/$SERVICE-admin.ini" << EOF
[uwsgi]
master = true
plugin = python3
thunder-lock = true
processes = 5
threads = 2
chmod-socket = 660
chown-socket = $SERVICE:www-data

name = $SERVICE
uid = $SERVICE
gid = www-data

chdir = /var/www/$SERVICE/  
virtualenv = /var/lib/$SERVICE/venv
wsgi-file = /var/lib/$SERVICE/venv/bin/$SERVICE-wsgi-admin

no-orphans = true
vacuum = true
EOF

  sudo ln -s /etc/uwsgi/apps-{available,enabled}/$SERVICE-admin.ini
fi

sudo bash -c "cat > /etc/uwsgi/apps-available/$SERVICE.ini" << EOF
[uwsgi]
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
wsgi-file = /var/lib/$SERVICE/venv/bin/$SERVICE-wsgi-public

no-orphans = true
vacuum = true
EOF

sudo ln -s /etc/uwsgi/apps-{available,enabled}/$SERVICE.ini

sudo systemctl restart uwsgi

# nginx

sudo bash -c "cat > /etc/nginx/sites-available/$SERVICE.conf" << EOF
server {
    listen      $SERVICE_PORT;
    access_log  /var/log/nginx/$SERVICE/access.log;
    error_log   /var/log/nginx/$SERVICE/error.log;

    location / {
        uwsgi_pass    unix:///run/uwsgi/app/$SERVICE/socket;
        include       uwsgi_params;
    }
}
EOF

[[ $SERVICE_ADMIN_PORT == disabled ]] || sudo bash -c "cat >> /etc/nginx/sites-available/$SERVICE.conf" << EOF
server {
    listen      $SERVICE_ADMIN_PORT;
    access_log  /var/log/nginx/$SERVICE/access.log;
    error_log   /var/log/nginx/$SERVICE/error.log;

    location / {
        uwsgi_pass    unix:///run/uwsgi/app/$SERVICE-admin/socket;
        include       uwsgi_params;
    }
}
EOF

sudo ln -s /etc/nginx/sites-{available,enabled}/$SERVICE.conf
sudo sed -i "s/worker_processes auto/worker_processes 6/" /etc/nginx/nginx.conf

sudo systemctl restart nginx

# cleanup

sudo rm -rf /var/lib/$SERVICE/src
sudo rm -rf /var/lib/$SERVICE/patch

cd $OLD_PWD
