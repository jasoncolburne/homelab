#!/usr/bin/bash

set -euo pipefail

OLD_PWD=$(pwd)

sudo systemctl stop uwsgi

sudo rm -rf \
  /etc/$SERVICE \
  /var/log/$SERVICE \
  /var/log/nginx/$SERVICE \
  /var/www/$SERVICE

sudo rm -f \
  /etc/nginx/sites-enabled/$SERVICE* \
  /etc/nginx/sites-available/$SERVICE* \
  /etc/uwsgi/apps-enabled/$SERVICE* \
  /etc/uwsgi/apps-available/$SERVICE* \
  /var/log/uwsgi/apps/$SERVICE*

sudo -u postgres psql -q -c "DROP DATABASE $SERVICE"
sudo -u postgres psql -q -c "DROP ROLE $SERVICE"

sudo userdel $SERVICE

cd $OLD_PWD