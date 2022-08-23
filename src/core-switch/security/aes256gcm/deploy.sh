#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

mkdir -p ~/bin
gcc -Wall -o ~/bin/aes256gcm ~/install/security/aes256gcm.c -lcrypto
gcc -Wall -o ~/bin/aes256gcm-decrypt ~/install/security/aes256gcm-decrypt.c -lcrypto