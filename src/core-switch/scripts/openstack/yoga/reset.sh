#!/usr/bin/bash

set -euo pipefail

SERVICE=keystone ~/install/scripts/openstack/yoga/reset-service.sh
SERVICE=glance ~/install/scripts/openstack/yoga/reset-service.sh
