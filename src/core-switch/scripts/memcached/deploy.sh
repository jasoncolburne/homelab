#!/usr/bin/bash
# https://www.rabbitmq.com/install-debian.html

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install memcached
sudo systemctl stop memcached
sudo systemctl disable memcached

sudo systemctl daemon-reload
