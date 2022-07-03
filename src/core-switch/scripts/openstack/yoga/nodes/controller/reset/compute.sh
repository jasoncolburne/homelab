#!/usr/bin/bash

set -euo pipefail

sudo systemctl stop nova-scheduler || true
sudo systemctl stop nova-conductor || true
sudo systemctl stop nova-novncproxy || true
sudo rm -f /lib/systemd/system/nova-{scheduler,conductor,novncproxy}.service
sudo systemctl daemon-reload

sudo systemctl stop os-fwd-${SERVICE} nginx-ctrl uwsgi-${SERVICE} || true

sudo rm -rf \
  /etc/$SERVICE \
  /var/log/nginx/$SERVICE \
  /var/www/$SERVICE \
  /var/lib/$SERVICE/instances

sudo rm -f \
  /etc/nginx/ctrl/sites-enabled/$SERVICE* \
  /etc/nginx/ctrl/sites-available/$SERVICE* \
  /etc/uwsgi/apps-enabled/$SERVICE* \
  /etc/uwsgi/apps-available/$SERVICE* \
  /var/log/uwsgi/apps/$SERVICE* \
  /lib/systemd/system/uwsgi-${SERVICE}* \
  /lib/systemd/system/os-fwd-${SERVICE}*

sudo cat /etc/postgresql/13/main/pg_hba.conf | rg -v "^hostssl ${SERVICE}" > ~/pg_hba.conf
sudo mv -v ~/pg_hba.conf /etc/postgresql/13/main
sudo chown postgres:postgres /etc/postgresql/13/main/pg_hba.conf
sudo chmod 640 /etc/postgresql/13/main/pg_hba.conf

sudo userdel $SERVICE || true

sudo systemctl daemon-reload
sudo systemctl restart postgresql

(sudo ip netns exec amqp sudo rabbitmqctl list_users | rg openstack) \
  && sudo ip netns exec amqp sudo rabbitmqctl delete_user openstack \
  || true

DATABASES=($SERVICE $SERVICE"_api" $SERVICE"_cell0")
for DATABASE in "${DATABASES[@]}"
do
  sudo -u postgres psql -q -c "DROP DATABASE \"$DATABASE\"" || true
done
sudo -u postgres psql -q -c "DROP ROLE $SERVICE" || true
