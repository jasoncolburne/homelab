#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPTS_DIR=~/install/scripts
INFRASTRUCTURE_DIR=${SCRIPTS_DIR}/infrastructure
OPENSTACK_DIR=${SCRIPTS_DIR}/openstack/yoga

${INFRASTRUCTURE_DIR}/up.sh
${OPENSTACK_DIR}/up.sh
