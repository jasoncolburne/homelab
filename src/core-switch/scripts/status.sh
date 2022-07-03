#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo systemctl status \
  os-fwd-keystone \
  os-fwd-glance \
  os-fwd-placement \
  os-fwd-nova \
  nginx-ctrl \
  uwsgi-keystone \
  uwsgi-keystone-admin \
  uwsgi-glance \
  uwsgi-placement \
  uwsgi-nova \
  nova-scheduler \
  nova-conductor \
  nova-novncproxy \
  memcached \
  rabbitmq-server \
  zookeeper \
  kafka \
  postgresql \
