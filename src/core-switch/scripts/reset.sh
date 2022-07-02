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

${OPENSTACK_DIR}/reset.sh
${INFRASTRUCTURE_DIR}/down.sh
sudo ${NETWORK_DIR}/destroy.sh