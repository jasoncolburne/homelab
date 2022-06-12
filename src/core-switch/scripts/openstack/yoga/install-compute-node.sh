#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~/src/$SERVICE-compute
git branch | rg debian-bullseye || git switch -c debian-bullseye

[[ -f /var/lib/$SERVICE/venv-node/bin/activate ]] || python3 -m venv /var/lib/$SERVICE/venv-node
. /var/lib/$SERVICE/venv-node/bin/activate

pip install -r requirements.txt
# requirements for our setup
pip install psycopg2 python-memcached
python3 setup.py install

deactivate
