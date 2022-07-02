#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

for SERVICE_PATH in /lib/systemd/system/os-fwd-*
do
  SERVICE=$(basename ${SERVICE_PATH})
  sudo systemctl stop ${SERVICE}
done

sudo systemctl stop nginx-ctrl

for SERVICE_PATH in /lib/systemd/system/uwsgi-*
do
  SERVICE=$(basename ${SERVICE_PATH})
  sudo systemctl stop ${SERVICE}
done
