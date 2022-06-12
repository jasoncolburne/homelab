#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  rabbitmq-server \
  libvirt-daemon-system \
  libvirt-dev
