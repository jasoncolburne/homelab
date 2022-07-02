#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~/src/$SERVICE
git branch | rg debian-bullseye || git switch -c debian-bullseye

if [[ -d etc/$SERVICE ]]
then
  SOURCE_CONFIG_PATH=etc/$SERVICE
else
  SOURCE_CONFIG_PATH=etc
fi

([[ ! -f $SOURCE_CONFIG_PATH/$SERVICE.conf.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genconfig
([[ ! -f $SOURCE_CONFIG_PATH/policy.yaml.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genpolicy
# tox -e docs
# tox -e protection

cp -R $SOURCE_CONFIG_PATH/* /etc/$SERVICE
MAIN_CONFIG_FILE_NAME=$SERVICE.conf

MGMT_IP=$(rg os-ctrl-mgmt /etc/hosts | cut -d " " -f1)
if [[ -f ~/patch/$MAIN_CONFIG_FILE_NAME.patch ]]
then
  patch -o /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME.sample < ~/patch/$MAIN_CONFIG_FILE_NAME.patch
  sed -i "s/POSTGRES_PASSPHRASE/$POSTGRES_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_KEYSTONE_HOST/$KEYSTONE_HOST/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_KEYSTONE_PORT/$KEYSTONE_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_MEMCACHE_PORT/$MEMCACHE_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_SERVICE_PASSPHRASE/$SERVICE_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_PASSPHRASE/$RABBIT_OPENSTACK_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_HOST/$AMQP_HOST/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_RABBIT_PORT/$AMQP_PORT/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_HOST_IP/$MGMT_IP/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_REGION/$REGION/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_PLACEMENT_PASSPHRASE/$PLACEMENT_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_NEUTRON_PASSPHRASE/$NEUTRON_PASSPHRASE/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
  sed -i "s/SERVICE_INSTALL_METADATA_SECRET/$METADATA_SECRET/g" /etc/$SERVICE/$MAIN_CONFIG_FILE_NAME
fi

[[ -f /var/lib/$SERVICE/venv/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv
source /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2 python-memcached libvirt-python
python3 setup.py install

$SERVICE-manage api_db sync
$SERVICE-manage cell_v2 map_cell0
$SERVICE-manage cell_v2 create_cell --name=cell1 --verbose
$SERVICE-manage db sync

deactivate
