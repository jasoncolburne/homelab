#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install uwsgi uwsgi-plugin-python3

sudo systemctl stop uwsgi
sudo systemctl disable uwsgi

sudo systemctl daemon-reload
