#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo systemctl restart \
  uwsgi-keystone \
  uwsgi-keystone-admin \
  uwsgi-glance

sudo systemctl restart nginx-ctrl

sudo systemctl restart \
  os-fwd-keystone \
  os-fwd-glance
