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
  uwsgi \
  uwsgi-plugin-python3 \
  libldap2-dev \
  libsasl2-dev \
  python3-openstackclient
