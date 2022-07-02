#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~/src/$SERVICE
git branch | rg debian-bullseye || git switch -c debian-bullseye

([[ ! -f etc/$SERVICE-api.conf.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genconfig
([[ ! -f etc/policy.yaml.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genpolicy
# tox -e docs
# tox -e protection

cp -R etc/* /etc/$SERVICE

patch -o /etc/$SERVICE/${SERVICE}-api.conf /etc/$SERVICE/${SERVICE}-api.conf.sample < ~/patch/${SERVICE}-api.conf.patch
sed -i "s/POSTGRES_PASSPHRASE/${POSTGRES_PASSPHRASE}/g" /etc/$SERVICE/${SERVICE}-api.conf
sed -i "s/SERVICE_INSTALL_KEYSTONE_HOST/$KEYSTONE_HOST/g" /etc/$SERVICE/${SERVICE}-api.conf
sed -i "s/SERVICE_INSTALL_KEYSTONE_PORT/$KEYSTONE_PORT/g" /etc/$SERVICE/${SERVICE}-api.conf
sed -i "s/SERVICE_INSTALL_MEMCACHE_PORT/$MEMCACHE_PORT/g" /etc/$SERVICE/${SERVICE}-api.conf
sed -i "s/SERVICE_INSTALL_SERVICE_PASSPHRASE/$SERVICE_PASSPHRASE/g" /etc/$SERVICE/${SERVICE}-api.conf

[[ -f /var/lib/$SERVICE/venv/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv
. /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2 python-memcached
python3 setup.py install

$SERVICE-manage db_sync

deactivate
