#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

derive_hdd_passphrase() {
  local HDD_NAME=$1

  echo -n "enter a passphrase for ${HDD_NAME}: "
  STTY_ORIG=$(stty -g)
  stty -echo
  IFS= read -r PASSPHRASE
  stty "${STTY_ORIG}"
  echo

  echo -n "verify: "
  STTY_ORIG=$(stty -g)
  stty -echo
  IFS= read -r VERIFICATION
  stty "${STTY_ORIG}"
  echo

  if [[ "${PASSPHRASE}" != "${VERIFICATION}" ]]; then
    echo "passphrases did not match!"
    exit 1
  fi
  unset VERIFICATION

  echo "deriving key..."
  # we use a null salt so that we can recover the drive with only the passphrase, this is atypical salt usage
  export HDD_PASSPHRASE=$(echo -n "${PASSPHRASE}" | argon2 '\0\0\0\0\0\0\0\0' -id -e -t 10 -m 20 -p 8 | cut -d'$' -f6 | tr -d '\n')
  unset PASSPHRASE
}

setup() {
  local HDD_NAME=$1

  derive_hdd_passphrase "${HDD_NAME}"
  echo -n "${HDD_PASSPHRASE}" | sudo clevis encrypt tpm2 '{"pcr_bank":"sha256","pcr_ids":"0,2,3,4,6,7,8"}' | sudo dd of=/etc/sedutil/${HDD_NAME}.passphrase.enc

  if [[ "${INITIALIZE_HDDS:-0}" == "1" ]]; then
    PASSPHRASE_LABEL=PSID_${HDD_NAME}
    CURRENT_PASSPHRASE="${!PASSPHRASE_LABEL}"

    sudo sedutil-cli --PSIDrevert "${CURRENT_PASSPHRASE}" /dev/${HDD_NAME}
    sudo sedutil-cli --initialSetup "${HDD_PASSPHRASE}" /dev/${HDD_NAME}

    sudo sedutil-cli --enableLockingRange 0 "${HDD_PASSPHRASE}" /dev/${HDD_NAME}
    sudo sedutil-cli --setMBREnable off "${HDD_PASSPHRASE}" /dev/${HDD_NAME}
    sudo sedutil-cli --setMBRDone off "${HDD_PASSPHRASE}" /dev/${HDD_NAME}
  fi
  unset HDD_PASSPHRASE
}

sudo mkdir -p /etc/sedutil
setup "nvme0"
setup "nvme1"

sudo mkdir -p /usr/lib/dracut/modules.d/60unlock-sed
sudo cp ~/install/scripts/security/sedutil/module-setup.sh /usr/lib/dracut/modules.d/60unlock-sed
sudo cp ~/install/scripts/security/sedutil/unlock-sed.sh /usr/lib/dracut/modules.d/60unlock-sed

sudo dracut -f --regenerate-all -v
