#!/usr/bin/bash

set -euo pipefail

# SERVICE=neutron ~/install/scripts/openstack/yoga/reset-network-service.sh
# SERVICE=nova ~/install/scripts/openstack/yoga/reset-compute-node.sh
# SERVICE=nova ~/install/scripts/openstack/yoga/reset-compute-service.sh
SERVICE=placement ~/install/scripts/openstack/yoga/nodes/controller/reset/placement.sh
SERVICE=glance ~/install/scripts/openstack/yoga/nodes/controller/reset/image.sh
SERVICE=keystone ~/install/scripts/openstack/yoga/nodes/controller/reset/identity.sh
