#!/usr/bin/bash

set -euo pipefail

sudo systemctl stop nginx
sudo systemctl stop uwsgi
sudo systemctl stop neutron-linuxbridge-agent || true
sudo systemctl stop neutron-dhcp-agent || true
sudo systemctl stop neutron-metadata-agent || true
sudo systemctl stop neutron-l3-agent || true
sudo rm -f /lib/systemd/system/neutron-linuxbridge-agent.service /lib/systemd/system/neutron-dhcp-agent.service /lib/systemd/system/neutron-metadata-agent.service /lib/systemd/system/neutron-l3-agent.service
sudo systemctl daemon-reload

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

sudo systemctl start uwsgi
sudo systemctl start nginx
