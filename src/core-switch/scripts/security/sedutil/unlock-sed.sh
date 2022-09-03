#!/bin/bash

set -euo pipefail

# Make sure to exit cleanly if SIGTERM is received.
trap 'echo "Exiting due to SIGTERM" && exit 0' TERM

derive_hdd_passphrase() {
  local HDD_NAME=$1

  # echo -n "enter the passphrase for ${HDD_NAME}: "
  # STTY_ORIG=$(stty -g)
  # stty -echo
  # IFS= read -r PASSPHRASE
  # stty "${STTY_ORIG}"
  # echo

  PASSPHRASE=$(systemd-ask-password "enter the passphrase for ${HDD_NAME}: ")

  echo "deriving key..."
  # we use a null salt so that we can recover the drive with only the passphrase, this is atypical salt usage
  export HDD_PASSPHRASE=$(echo -n "${PASSPHRASE}" | argon2 '\0\0\0\0\0\0\0\0' -id -e -t 10 -m 20 -p 8 | cut -d'$' -f6 | tr -d '\n')
  unset PASSPHRASE
}

unlock() {
  local HDD_NAME=$1

  LOCKED=$(sedutil-cli --query /dev/${HDD_NAME} | grep Locked | cut -d',' -f1 | cut -d'=' -f2 | sed 's/ //g')

  if [[ "${LOCKED}" == "Y" ]]; then
    HDD_PASSPHRASE=$( (cat /etc/sedutil/${HDD_NAME}.passphrase.enc | clevis decrypt) || true )
    sedutil-cli --setLockingRange 0 rw "${HDD_PASSPHRASE}" /dev/${HDD_NAME} || true
    unset HDD_PASSPHRASE

    LOCKED=$(sedutil-cli --query /dev/${HDD_NAME} | grep Locked | cut -d',' -f1 | cut -d'=' -f2 | sed 's/ //g')

    if [[ "${LOCKED}" == "Y" ]]; then
      derive_hdd_passphrase "${HDD_NAME}"
      sedutil-cli --setLockingRange 0 rw "${HDD_PASSPHRASE}" /dev/${HDD_NAME}
    fi

    echo "successfully unlocked /dev/${HDD_NAME}" >&2

    partprobe /dev/${HDD_NAME}n1
  else
    echo "/dev/${HDD_NAME} is already unlocked. continuing." >&2
  fi
}

echo "unlocking nvme drives" >&2
unlock "nvme0"
unlock "nvme1"

exit 0
