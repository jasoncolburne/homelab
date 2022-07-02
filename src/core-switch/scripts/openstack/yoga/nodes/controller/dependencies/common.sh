#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  python3-pip \
  python3-venv \
  python3-dev \
  libpq-dev \
  openssl \
  uwsgi \
  uwsgi-plugin-python3 \
  tox \
  python3-openstackclient
