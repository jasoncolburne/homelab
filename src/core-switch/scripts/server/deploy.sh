#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPTS_DIR=~/install/scripts
SERVER_DIR=${SCRIPTS_DIR}/server

TARGETS=(uwsgi nginx)

for TARGET in "${TARGETS[@]}"
do
  ${SERVER_DIR}/${TARGET}/deploy.sh
done
