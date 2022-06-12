#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

export KEYSTONE_HOST=$(hostname -f)
export KEYSTONE_PORT=5000
export MEMCACHE_PORT=11211
export RABBIT_HOST=$(hostname -f)
export RABBIT_PORT=5672
export METADATA_HOST=$(hostname -f)

SERVICE=keystone SERVICE_PORT=$KEYSTONE_PORT SERVICE_ADMIN_PORT=35357 ~/install/scripts/openstack/yoga/deploy-identity-service.sh
SERVICE=glance SERVICE_TYPE=image SERVICE_PORT=9292 WSGI_SCRIPT=glance-wsgi-api DESCRIPTION="OpenStack Image API (glance)" ~/install/scripts/openstack/yoga/deploy-api-service.sh
export PLACEMENT_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
SERVICE=placement SERVICE_TYPE=placement SERVICE_PORT=8778 WSGI_SCRIPT=placement-api DESCRIPTION="OpenStack Placement API (placement)" ~/install/scripts/openstack/yoga/deploy-api-service.sh
export NOVA_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
export NEUTRON_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
export RABBIT_PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
export METADATA_SECRET=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
SERVICE=nova SERVICE_TYPE=compute SERVICE_PORT=8774 WSGI_SCRIPT=nova-api-wsgi DESCRIPTION="OpenStack Compute API (nova)" ~/install/scripts/openstack/yoga/deploy-compute-service.sh
unset PLACEMENT_PASSPHRASE
SERVICE=nova ~/install/scripts/openstack/yoga/deploy-compute-node.sh
SERVICE=neutron SERVICE_TYPE=network SERVICE_PORT=9696 WSGI_SCRIPT=neutron-api DESCRIPTION="OpenStack Network API (neutron)" ~/install/scripts/openstack/yoga/deploy-network-service.sh
unset NOVA_PASSPHRASE
unset METADATA_SECRET
unset RABBIT_PASSPHRASE

unset KEYSTONE_HOST
unset KEYSTONE_PORT
unset MEMCACHE_PORT
unset RABBIT_HOST
unset RABBIT_PORT
