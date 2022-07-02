#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo systemctl restart zookeeper kafka memcached postgresql rabbitmq-server
