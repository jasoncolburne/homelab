#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPTS_DIR=~/install/scripts
INFRASTRUCTURE_DIR=${SCRIPTS_DIR}/infrastructure
NETWORK_DIR=${SCRIPTS_DIR}/network
OPENSTACK_DIR=${SCRIPTS_DIR}/openstack/yoga
SERVER_DIR=${SCRIPTS_DIR}/server

sudo DEBUG=${DEBUG} ${NETWORK_DIR}/build.sh
${INFRASTRUCTURE_DIR}/deploy.sh
${INFRASTRUCTURE_DIR}/up.sh
${SERVER_DIR}/deploy.sh
${OPENSTACK_DIR}/deploy.sh
