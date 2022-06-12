#!/usr/bin/bash

set -euo pipefail

sudo systemctl stop nova-scheduler || true
sudo systemctl stop nova-conductor || true
sudo rm -f /lib/systemd/system/nova-scheduler.service /lib/systemd/system/nova-conductor.service
sudo systemctl daemon-reload

sudo systemctl stop nginx
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

(sudo rabbitmqctl list_users | rg openstack) && sudo rabbitmqctl delete_user openstack || true

DATABASES=($SERVICE $SERVICE"_api" $SERVICE"_cell0")
for DATABASE in "${DATABASES[@]}"
do
  sudo -u postgres psql -q -c "DROP DATABASE \"$DATABASE\""
done
sudo -u postgres psql -q -c "DROP ROLE $SERVICE"

sudo userdel $SERVICE

sudo systemctl start uwsgi
sudo systemctl start nginx
