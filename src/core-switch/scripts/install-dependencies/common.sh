#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  python3-pip \
  python3-venv \
  python3-dev \
  memcached \
  postgresql \
  libpq-dev \
  nginx \
  openssl \
  uwsgi \
  uwsgi-plugin-python3 \
  python3-openstackclient
