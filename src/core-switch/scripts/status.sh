#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo systemctl status \
  uwsgi-keystone \
  uwsgi-keystone-admin \
  uwsgi-glance \
  nginx-ctrl \
  os-fwd-keystone \
  os-fwd-glance \
  zookeeper \
  kafka \
  memcached \
  postgresql \
  rabbitmq-server
