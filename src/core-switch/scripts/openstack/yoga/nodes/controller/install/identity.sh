#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~/src/$SERVICE
git branch | rg debian-bullseye || git switch -c debian-bullseye

([[ ! -f etc/$SERVICE.conf.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genconfig
([[ ! -f etc/$SERVICE.policy.yaml.sample ]] || [[ $REBUILD == "1" ]]) && tox -e genpolicy
# tox -e docs
# tox -e protection

cp -R etc/* /etc/$SERVICE
if [[ -f ~/patch/$SERVICE.conf.patch ]]
then
  sed -i "s/POSTGRES_PASSPHRASE/${POSTGRES_PASSPHRASE}/" ~/patch/${SERVICE}.conf.patch
  patch -o /etc/$SERVICE/$SERVICE.conf /etc/$SERVICE/$SERVICE.conf.sample < ~/patch/$SERVICE.conf.patch
fi

[[ -f /var/lib/$SERVICE/venv/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv
source /var/lib/$SERVICE/venv/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2
python3 setup.py install

$SERVICE-manage db_sync
$SERVICE-manage fernet_setup
$SERVICE-manage credential_setup

# this is very keystone specific and will need to be abstracted
$SERVICE-manage bootstrap \
  --bootstrap-password=$SERVICE_ADMIN_PASSPHRASE \
  --bootstrap-admin-url https://os-ctrl-mgmt:$SERVICE_ADMIN_PORT/v3/ \
  --bootstrap-internal-url https://os-ctrl-mgmt:$SERVICE_PORT/v3/ \
  --bootstrap-public-url https://$(hostname -f):$SERVICE_PORT/v3/ \
  --bootstrap-region-id $REGION

deactivate
