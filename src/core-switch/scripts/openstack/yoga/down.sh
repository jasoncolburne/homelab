#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo systemctl stop \
  os-fwd-keystone \
  os-fwd-glance

sudo systemctl stop nginx-ctrl

sudo systemctl stop \
  uwsgi-keystone \
  uwsgi-keystone-admin \
  uwsgi-glance
