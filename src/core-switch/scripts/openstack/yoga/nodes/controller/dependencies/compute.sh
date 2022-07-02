#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  libvirt-daemon-system \
  libvirt-dev
