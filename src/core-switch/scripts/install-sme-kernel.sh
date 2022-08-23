#!/usr/bin/bash

set -euo pipefail

sudo apt-get -y install sbsigntool

cd ~
tar xzvf kernel.tgz

cd ~/kernel
sudo apt-get -y install ./linux-image-*-sme-amd64_*_amd64.deb
sudo apt-get -y install ./linux-headers-*-sme-amd64_*_amd64.deb

VERSION=$(echo linux-image-*-sme-amd64_*_amd64.deb | sed -E 's/linux-image-(.+-sme-amd64)_.+_amd64\.deb/\1/')
SHORT_VERSION=$(echo $VERSION | cut -d'.' -f1-2)
MODULES_DIR=/lib/modules/${VERSION}

PATH_VERSION=$(echo linux-image-*-sme-amd64_*_amd64.deb | sed -E 's/linux-image-.+-sme-amd64_(.+)-.+_amd64\.deb/\1/')

echo -n "Enter MOK passphrase: "
read -s KBUILD_SIGN_PIN
export KBUILD_SIGN_PIN

for MODULE in $(find ${MODULES_DIR} -type f -name '*.ko*'); do
    (modinfo "${MODULE}" | rg "signer:\s+core") || \
    (echo "signing ${MODULE}"; sudo --preserve-env=KBUILD_SIGN_PIN ${MODULES_DIR}/build/scripts/sign-file sha256 /var/lib/shim-signed/mok/MOK.priv /var/lib/shim-signed/mok/MOK.der "${MODULE}")
done

sudo grub-set-default "Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux ${VERSION}"
sudo update-grub

cd /var/lib/shim-signed/mok
sudo sbsign --key MOK.priv --cert MOK.pem "/boot/vmlinuz-${VERSION}" --output "/boot/vmlinuz-${VERSION}.tmp"
cd ~
sudo mv "/boot/vmlinuz-${VERSION}.tmp" "/boot/vmlinuz-${VERSION}"
sudo dracut -f --regenerate-all -v

echo "now you'll need to reboot and configure/update clevis/luks, after typing your passwords"
echo "for example,"
echo "  sudo clevis luks bind -d /dev/sda3 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
echo "  sudo clevis luks bind -d /dev/sda4 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
echo "  sudo clevis luks bind -d /dev/md0 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
echo "or"
echo "  sudo clevis luks unbind -d /dev/sda3 -s 1"
echo "  sudo clevis luks unbind -d /dev/sda4 -s 1"
echo "  sudo clevis luks unbind -d /dev/md0 -s 1"
echo "  sudo clevis luks bind -d /dev/sda3 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
echo "  sudo clevis luks bind -d /dev/sda4 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
echo "  sudo clevis luks bind -d /dev/md0 tpm2 '{\"pcr_bank\":\"sha256\",\"pcr_ids\":\"0,1,2,3,4,5,6,7\"}'"
