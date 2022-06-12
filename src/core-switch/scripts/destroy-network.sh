#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cleanup_network() {
  local NETWORK=$1

  for NODE in "${NODES[@]}"
  do
    ip netns exec ${NODE} ip link delete ${NODE}-${NETWORK} || true
  done

  if [[ "${NETWORK}" != "ext" ]]
  then
    ip link delete br-${NETWORK} || true
  fi
}

ip link delete ext-to-api || true
NODES=(net)
cleanup_network ext
NODES=(ctrl dash)
cleanup_network api
NODES=(net comp)
cleanup_network data
NODES=(ctrl net comp dash)
cleanup_network mgmt

for NODE in "${NODES[@]}"
do
  ip netns del ${NODE} || true
done
