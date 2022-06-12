#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

. ~/.openrc-admin
openstack project create --domain default --description "Distributed Quantum Computer" quantum
KEYSTONE_HOST=$(hostname -f)
KEYSTONE_PORT=5000
PASSPHRASE=$(dd if=/dev/urandom bs=32 count=1 | base64 | tr / -)
openstack user create --domain default --password $PASSPHRASE jason
openstack role add --project quantum --user jason admin
cat > ~/.openrc-quantum << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=quantum
export OS_USERNAME=jason
export OS_PASSWORD=$PASSPHRASE
export OS_AUTH_URL=https://$KEYSTONE_HOST:$KEYSTONE_PORT/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
unset PASSPHRASE
