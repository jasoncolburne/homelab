#!/usr/bin/bash

set -euo pipefail

sudo systemctl stop os-fwd-${SERVICE} nginx-ctrl uwsgi-${SERVICE} || true

sudo rm -rf \
  /etc/$SERVICE \
  /var/log/nginx/$SERVICE \
  /var/www/$SERVICE

sudo rm -f \
  /etc/nginx/ctrl/sites-enabled/$SERVICE* \
  /etc/nginx/ctrl/sites-available/$SERVICE* \
  /etc/uwsgi/apps-enabled/$SERVICE* \
  /etc/uwsgi/apps-available/$SERVICE* \
  /var/log/uwsgi/apps/$SERVICE* \
  /var/lib/$SERVICE/images/* \
  /lib/systemd/system/uwsgi-${SERVICE}* \
  /lib/systemd/system/os-fwd-${SERVICE}*

sudo cat /etc/postgresql/13/main/pg_hba.conf | rg -v "^hostssl ${SERVICE}" > ~/pg_hba.conf
sudo mv -v ~/pg_hba.conf /etc/postgresql/13/main
sudo chown postgres:postgres /etc/postgresql/13/main/pg_hba.conf
sudo chmod 640 /etc/postgresql/13/main/pg_hba.conf

sudo userdel $SERVICE || true

sudo systemctl daemon-reload
sudo systemctl restart postgresql

sudo -u postgres psql -q -c "DROP DATABASE $SERVICE" || true
sudo -u postgres psql -q -c "DROP ROLE $SERVICE" || true
