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
    LINK_NAME=${NODE}-${NETWORK}

    ip netns exec ${NODE} ip link delete ${LINK_NAME} || true
    ip link delete ${LINK_NAME} || true
    if rg ${LINK_NAME} /etc/hosts
    then
      sed -i "s/^\([^#].*${LINK_NAME}\)$/#\1/" /etc/hosts
    fi
  done

  if [[ "${NETWORK}" != "ext" ]]
  then
    ip link delete br-${NETWORK} || true
  fi
}

ip link delete ext-to-api || true
ip link delete host-mgmt || true
NODES=(os-net)
cleanup_network ext
NODES=(os-ctrl os-dash)
cleanup_network api
NODES=(os-ctrl os-dash os-net os-comp1 os-comp2 os-store ak-kafka ak-zoo amqp pgsql mem)
cleanup_network infr
NODES=(os-net os-comp1 os-comp2 os-store)
cleanup_network data
NODES=(os-ctrl os-dash os-net os-comp1 os-comp2 os-store)
cleanup_network mgmt

NODES=(os-ctrl os-dash os-net os-comp1 os-comp2 ak-kafka ak-zoo amqp pgsql)
for NODE in "${NODES[@]}"
do
  ip netns del ${NODE} || true
done
