#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~/src/$SERVICE
git branch | rg debian-bullseye || git switch -c debian-bullseye

SOURCE_CONFIG_PATH=etc
( ([[ ! -f $SOURCE_CONFIG_PATH/$SERVICE.conf.sample ]] && [[ ! -f $SOURCE_CONFIG_PATH/$SERVICE-api.conf.sample ]]) || [[ $REBUILD == "1" ]] ) && tox -e genconfig
([[ ! -f $SOURCE_CONFIG_PATH/policy.yaml.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genpolicy
# tox -e docs
# tox -e protection

cp -R $SOURCE_CONFIG_PATH/* /etc/$SERVICE
mv /etc/$SERVICE/$SERVICE/* /etc/$SERVICE
rm -rf /etc/$SERVICE/$SERVICE
MAIN_CONFIG_FILE_NAME=$SERVICE.conf

if [[ -f ~/patch/$MAIN_CONFIG_FILE_NAME.patch ]]
then
  patch -o /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME.sample < ~/patch/$MAIN_CONFIG_FILE_NAME.patch
  sed -i "s/SERVICE_INSTALL_KEYSTONE_HOST/$KEYSTONE_HOST/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_KEYSTONE_PORT/$KEYSTONE_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_MEMCACHE_PORT/$MEMCACHE_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_SERVICE_PASSPHRASE/$SERVICE_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_PASSPHRASE/$RABBIT_OPENSTACK_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_HOST/$RABBIT_HOST/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_PORT/$RABBIT_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_REGION/$REGION/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_NOVA_PASSPHRASE/$NOVA_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
fi

if [[ -f ~/patch/metadata_agent.ini.patch ]]
then
  patch -o /etc/$SERVICE/metadata_agent.ini /etc/$SERVICE/metadata_agent.ini.sample < ~/patch/metadata_agent.ini.patch
  sed -i "s/SERVICE_INSTALL_METADATA_HOST/$METADATA_HOST/g" /etc/$SERVICE/metadata_agent.ini
  sed -i "s/SERVICE_INSTALL_METADATA_SECRET/$METADATA_SECRET/g" /etc/$SERVICE/metadata_agent.ini
fi

mkdir -p /etc/$SERVICE/plugins/ml2

cat > /etc/$SERVICE/plugins/ml2/ml2_conf.ini << EOF
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vxlan]
vni_ranges = 1:1000

[security]
enable_ipset = true
EOF

HOST_IP=$(hostname -I | awk '{print $1}')
cat > /etc/$SERVICE/plugins/ml2/linuxbridge_agent.ini << EOF
[linux_bridge]
physical_interface_mappings = provider:$PUBLIC_NETWORK_INTERFACE

[vxlan]
enable_vxlan = true
local_ip = $HOST_IP
l2_population = true

[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF

cat > /etc/$SERVICE/l3_agent.ini << EOF
[DEFAULT]
interface_driver = linuxbridge
EOF

cat > /etc/$SERVICE/dhcp_agent.ini << EOF
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
EOF

[[ -f /var/lib/$SERVICE/venv/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv
. /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2 python-memcached

python3 setup.py install

neutron-db-manage --config-file /etc/$SERVICE/$SERVICE.conf --config-file /etc/$SERVICE/plugins/ml2/ml2_conf.ini upgrade head

deactivate
