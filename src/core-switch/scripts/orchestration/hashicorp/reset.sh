#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]; then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y purge nomad vault consul
sudo rm -rf /opt/{nomad,consul,vault} /etc/{consul.d,vault.d,nomad.d}
sudo rm -f /lib/systemd/system/{nomad,consul}.service
sudo rm -f ~/.vault* ~/.consul*

sudo systemctl daemon-reload
