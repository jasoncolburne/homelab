#!/usr/bin/bash

set -euxo pipefail

cd ~/src/$SERVICE
git branch | rg debian-bullseye || git switch -c debian-bullseye

([[ ! -f etc/$SERVICE-api.conf.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genconfig
# tox -e docs
# tox -e protection

HOST=$(hostname -f)

cp -R etc/* /etc/$SERVICE
[[ -f ~/patch/$SERVICE-api.conf.patch ]] && patch -o /etc/$SERVICE/$SERVICE-api.conf /etc/$SERVICE/$SERVICE-api.conf.sample < ~/patch/$SERVICE-api.conf.patch
sed -i "s/SERVICE_INSTALL_KEYSTONE_HOST/$HOST/g" /etc/$SERVICE/$SERVICE-api.conf
sed -i "s/SERVICE_INSTALL_KEYSTONE_PORT/$KEYSTONE_PORT/g" /etc/$SERVICE/$SERVICE-api.conf
sed -i "s/SERVICE_INSTALL_SERVICE_PASSPHRASE/$SERVICE_PASSPHRASE/g" /etc/$SERVICE/$SERVICE-api.conf

[[ -f /var/lib/$SERVICE/venv/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv
. /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2
python3 setup.py install

$SERVICE-manage db_sync

deactivate
