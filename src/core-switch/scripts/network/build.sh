#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

create_virtual_network() {
  local NETWORK_NAME=$1
  local NETWORK_IPV4_PREFIX=$2
  local NETWORK_HARDWARE_PREFIX=$3
  local ASSIGN_IPS=$4
  local ADD_DEFAULT_ROUTES=$5

  # create network namespaces
  for NODE in "${NODES[@]}"
  do
    ip netns add ${NODE} || true
    ip netns exec ${NODE} sysctl -w net.ipv6.conf.all.disable_ipv6=1
    ip netns exec ${NODE} sysctl -w net.ipv6.conf.default.disable_ipv6=1
  done

  # create devices
  for NODE in "${NODES[@]}"
  do
    HARDWARE_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
    HARDWARE_SUFFIX="${!HARDWARE_SUFFIX_NAME}"
    ip link add ${NODE}-${NETWORK_NAME} type veth peer name ${NODE}-${NETWORK_NAME}-p
    ip link set ${NODE}-${NETWORK_NAME} address ${NETWORK_HARDWARE_PREFIX}${HARDWARE_SUFFIX}
  done
  ip link add br-${NETWORK_NAME} type bridge

  # add devices to network namespaces
  for NODE in "${NODES[@]}"
  do
    ip link set ${NODE}-${NETWORK_NAME} netns ${NODE}
  done

  # enslave peers
  for NODE in "${NODES[@]}"
  do
    ip link set dev ${NODE}-${NETWORK_NAME}-p master br-${NETWORK_NAME}
  done

  # assign ips
  if [[ -z "${FORCED_BRIDGE_IP}" ]]
  then
    BRIDGE_IP=${NETWORK_IPV4_PREFIX}1
  else
    BRIDGE_IP=${FORCED_BRIDGE_IP}
  fi
  
  if [[ "${ASSIGN_IPS}" == "1" ]]
  then
    for NODE in "${NODES[@]}"
    do
      IP_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
      IP_SUFFIX="${!IP_SUFFIX_NAME}"
      IP_ADDRESS=${NETWORK_IPV4_PREFIX}2${IP_SUFFIX}
      LINK_NAME=${NODE}-${NETWORK_NAME}

      ip netns exec ${NODE} ip addr add ${IP_ADDRESS}/24 dev ${LINK_NAME}
      if rg ${LINK_NAME} /etc/hosts
      then
        sed -i "s/^.*${LINK_NAME}$/${IP_ADDRESS} ${LINK_NAME}/" /etc/hosts
      else
        echo "${IP_ADDRESS} ${LINK_NAME}" >> /etc/hosts
      fi
    done
  fi

  # bring devices up
  for NODE in "${NODES[@]}"
  do
    ip netns exec ${NODE} ip link set dev lo up
    ip netns exec ${NODE} ip link set dev ${NODE}-${NETWORK_NAME} up
    ip link set dev ${NODE}-${NETWORK_NAME}-p up
  done
  ip link set dev br-${NETWORK_NAME} up

  if [[ "${ADD_DEFAULT_ROUTES}" == "1" ]]
  then
    for NODE in "${NODES[@]}"
    do
      ip netns exec ${NODE} ip route add 0.0.0.0/0 via ${NETWORK_IPV4_PREFIX}1
    done
  fi
}

OS_CTRL_ID=10   # controller
OS_DASH_ID=11   # dashboard
OS_NET_ID=12    # network
OS_COMP1_ID=13  # compute 1
OS_COMP2_ID=14  # compute 2
OS_STORE_ID=15  # storage

AK_KAFKA_ID=20  # kafka
AK_ZOO_ID=21    # zookeeper
AMQP_ID=22      # rabbitmq running amqp 1.0
MEM_ID=23       # memcached
PGSQL_ID=24     # postgresql

HOST_ID=30

# the above ids generate input for the last octet of the ip and virtual hardware
# addresses associated with each node.
#
# for ips, the above value is taken as decimal and added to 200.
# for example, every ip address on the dashboard node ends in 211.
# i did this because my external network's dhcp server's address range
# is capped somewhere around 175 by my choice
#
# for hardware addresses, the above value is interpreted as hex and used directly.
#
# the reason for the hex/decimal discrepency is because the goal of this is to be
# able to visually identify traffic.

# the second last octet of the hardware address
# corresponds to the following network mapping:
#
# ext - 01
# mgmt - 02
# api - 04
# data - 08

NETWORK_NAME=mgmt
NETWORK_IPV4_PREFIX=10.0.2.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:02:
NODES=(os-ctrl os-dash os-net os-comp1 os-comp2 os-store)
ASSIGN_IPS=1
ADD_DEFAULT_ROUTES=0
FORCED_BRIDGE_IP=
create_virtual_network "${NETWORK_NAME}" "${NETWORK_IPV4_PREFIX}" "${NETWORK_HARDWARE_PREFIX}" "${ASSIGN_IPS}" "${ADD_DEFAULT_ROUTES}"

NETWORK_NAME=infr
NETWORK_IPV4_PREFIX=10.0.4.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:04:
NODES=(os-ctrl os-dash os-net os-comp1 os-comp2 os-store ak-kafka ak-zoo amqp pgsql mem)
ASSIGN_IPS=1
ADD_DEFAULT_ROUTES=0
FORCED_BRIDGE_IP=
create_virtual_network "${NETWORK_NAME}" "${NETWORK_IPV4_PREFIX}" "${NETWORK_HARDWARE_PREFIX}" "${ASSIGN_IPS}" "${ADD_DEFAULT_ROUTES}"

NETWORK_NAME=data
NETWORK_IPV4_PREFIX=10.0.8.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:08:
NODES=(os-net os-comp1 os-comp2 os-store)
ASSIGN_IPS=0
ADD_DEFAULT_ROUTES=0
FORCED_BRIDGE_IP=
create_virtual_network "${NETWORK_NAME}" "${NETWORK_IPV4_PREFIX}" "${NETWORK_HARDWARE_PREFIX}" "${ASSIGN_IPS}" "${ADD_DEFAULT_ROUTES}"

NETWORK_NAME=api
NETWORK_IPV4_PREFIX=192.168.50.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:10:
NODES=(os-ctrl os-dash)
ASSIGN_IPS=1
ADD_DEFAULT_ROUTES=1
FORCED_BRIDGE_IP=192.168.50.251
create_virtual_network "${NETWORK_NAME}" "${NETWORK_IPV4_PREFIX}" "${NETWORK_HARDWARE_PREFIX}" "${ASSIGN_IPS}" "${ADD_DEFAULT_ROUTES}"

# snowflake configuration to connect network node to external network
NODE=os-net
NETWORK_NAME=ext
NETWORK_IPV4_PREFIX=192.168.50.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:01:
HARDWARE_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
HARDWARE_SUFFIX="${!HARDWARE_SUFFIX_NAME}"
IP_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
IP_SUFFIX="${!IP_SUFFIX_NAME}"
IP_ADDRESS=${NETWORK_IPV4_PREFIX}2${IP_SUFFIX}
LINK_NAME=${NODE}-${NETWORK_NAME}

ip link add ${LINK_NAME} type veth peer name ${LINK_NAME}-p
if rg ${LINK_NAME} /etc/hosts
then
  sed -i "s/^.*${LINK_NAME}$/${IP_ADDRESS} ${LINK_NAME}/" /etc/hosts
else
  echo "${IP_ADDRESS} ${LINK_NAME}" >> /etc/hosts
fi
ip link set ${LINK_NAME} address ${NETWORK_HARDWARE_PREFIX}${HARDWARE_SUFFIX}
ip link set ${LINK_NAME} netns ${NODE}
ip link set dev ${LINK_NAME}-p master br-${NETWORK_NAME}
ip netns exec ${NODE} ip addr add ${IP_ADDRESS}/24 dev ${LINK_NAME}
ip netns exec ${NODE} ip link set dev ${LINK_NAME} up
ip link set dev ${LINK_NAME}-p up
ip netns exec ${NODE} ip route add 0.0.0.0/0 via ${NETWORK_IPV4_PREFIX}1

# wire the api bridge to the external bridge
ip link add ext-to-api type veth peer name api-to-ext
ip link set dev ext-to-api master br-ext
ip link set dev api-to-ext master br-api
ip addr add 192.168.50.252/24 dev ext-to-api
ip addr add 192.168.50.253/24 dev api-to-ext
ip link set dev ext-to-api up
ip link set dev api-to-ext up

# wire the host to the management network
NODE=host
NETWORK_NAME=mgmt
NETWORK_IPV4_PREFIX=10.0.2.
NETWORK_HARDWARE_PREFIX=de:ad:be:ef:02:
HARDWARE_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
HARDWARE_SUFFIX="${!HARDWARE_SUFFIX_NAME}"
IP_SUFFIX_NAME="$(echo -n ${NODE} | tr [:lower:] [:upper:] | tr - _)_ID"
IP_SUFFIX="${!IP_SUFFIX_NAME}"
IP_ADDRESS=${NETWORK_IPV4_PREFIX}2${IP_SUFFIX}
LINK_NAME=${NODE}-${NETWORK_NAME}

ip link add ${LINK_NAME} type veth peer name ${LINK_NAME}-p
if rg ${LINK_NAME} /etc/hosts
then
  sed -i "s/^.*${LINK_NAME}$/${IP_ADDRESS} ${LINK_NAME}/" /etc/hosts
else
  echo "${IP_ADDRESS} ${LINK_NAME}" >> /etc/hosts
fi
ip link set ${LINK_NAME} address ${NETWORK_HARDWARE_PREFIX}${HARDWARE_SUFFIX}
ip link set dev ${LINK_NAME}-p master br-${NETWORK_NAME}
ip addr add ${IP_ADDRESS}/24 dev ${LINK_NAME}
ip link set dev ${LINK_NAME} up
ip link set dev ${LINK_NAME}-p up

PUBLIC_IP=$(ip addr show dev veth0 | head -n3 | tail -n1 | cut -d'/' -f1 | cut -d' ' -f6)
sudo sed -i "s/^.*$(hostname -f)\t$(hostname)/${PUBLIC_IP} $(hostname -f) $(hostname)/" /etc/hosts
