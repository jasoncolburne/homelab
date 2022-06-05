#!/usr/bin/bash

set -euo pipefail

apt-get -y install \
  memcached \
  libldap2-dev \
  libsasl2-dev
