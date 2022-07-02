#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPTS_DIR=~/install/scripts
INFRASTRUCTURE_DIR=${SCRIPTS_DIR}/infrastructure

TARGETS=(kafka memcached postgres rabbitmq)

for TARGET in "${TARGETS[@]}"
do
  ${INFRASTRUCTURE_DIR}/${TARGET}/deploy.sh
done
