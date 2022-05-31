#!/usr/bin/bash

set -euxo pipefail

SERVICE=keystone SERVICE_PORT=5000 SERVICE_ADMIN_PORT=35357 ~/install/scripts/deploy-openstack-yoga-service.sh
