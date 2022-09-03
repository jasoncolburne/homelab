#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get update
sudo apt-get install -y build-essential libssl-dev

mkdir -p ~/bin
gcc -Wall -o ~/bin/aes256gcm ~/install/scripts/security/aes256gcm/aes256gcm.c -lcrypto
gcc -Wall -o ~/bin/aes256gcm-decrypt ~/install/scripts/security/aes256gcm/aes256gcm-decrypt.c -lcrypto
