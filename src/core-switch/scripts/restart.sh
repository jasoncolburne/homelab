#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

SCRIPTS_DIR=~/install/scripts
${SCRIPTS_DIR}/down.sh
${SCRIPTS_DIR}/up.sh
