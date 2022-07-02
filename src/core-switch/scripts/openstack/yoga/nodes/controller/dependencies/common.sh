#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  python3-pip \
  python3-venv \
  python3-dev \
  libpq-dev \
  openssl \
  tox \
  python3-openstackclient
