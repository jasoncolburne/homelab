#!/usr/bin/bash

set -euxo pipefail

cd ~/src/$SERVICE
git switch -c debian-bullseye

tox -e genconfig
tox -e genpolicy
# tox -e docs
# tox -e protection

cp -R etc/* /etc/$SERVICE
patch -o /etc/$SERVICE/$SERVICE.conf /etc/$SERVICE/$SERVICE.conf.sample < ~/patch/$SERVICE.conf.patch

[[ -d /var/lib/$SERVICE/venv ]] || python3 -m venv /var/lib/$SERVICE/venv
. /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2
python3 setup.py install

$SERVICE-manage db_sync
$SERVICE-manage fernet_setup
$SERVICE-manage credential_setup

# this is very keystone specific and will need to be abstracted
$SERVICE-manage bootstrap \
  --bootstrap-password $SERVICE_ADMIN_PASSPHRASE \
  --bootstrap-admin-url https://$(hostname -f):$SERVICE_ADMIN_PORT/v3/ \
  --bootstrap-internal-url https://$(hostname -f):$SERVICE_PORT/v3/ \
  --bootstrap-public-url https://$(hostname -f):$SERVICE_PORT/v3/ \
  --bootstrap-region-id region-one

deactivate
