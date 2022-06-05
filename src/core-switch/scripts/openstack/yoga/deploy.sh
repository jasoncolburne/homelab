#!/usr/bin/bash

set -euxo pipefail

KEYSTONE_PORT=5000

SERVICE=keystone SERVICE_PORT=$KEYSTONE_PORT SERVICE_ADMIN_PORT=35357 ~/install/scripts/openstack/yoga/deploy-identity-service.sh
SERVICE=glance SERVICE_PORT=9292 KEYSTONE_PORT=$KEYSTONE_PORT DESCRIPTION="OpenStack Image (glance)" ~/install/scripts/openstack/yoga/deploy-api-service.sh
