#!/usr/bin/bash

set -euo pipefail

sudo systemctl stop nova-compute || true
sudo rm -f /lib/systemd/system/nova-compute.service
