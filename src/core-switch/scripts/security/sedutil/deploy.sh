#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get update
sudo apt-get install -y argon2 parted

cd ~/src
wget --content-disposition https://github.com/Drive-Trust-Alliance/exec/blob/master/sedutil_LINUX.tgz?raw=true
tar xzvf sedutil_LINUX.tgz
sudo cp sedutil/Release_x86_64/sedutil-cli /usr/sbin
