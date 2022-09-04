#!/usr/bin/bash

set -euo pipefail

install/scripts/security/sedutil/setup.sh

if [[ "${UNBIND:-0}" == "1" ]]; then
  sudo clevis luks unbind -d /dev/sda3 -s 1
  sudo clevis luks unbind -d /dev/sda4 -s 1
fi

# we can use at most 8 registers for a policy. i eliminated duplicates from the stable values to
# come up with exactly (luckily) 8 unique registers (0,1,4,6,7,8,9,14)
sudo clevis luks bind -d /dev/sda3 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,4,6,7,8,9,14"}'
sudo clevis luks bind -d /dev/sda4 tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,1,4,6,7,8,9,14"}'
