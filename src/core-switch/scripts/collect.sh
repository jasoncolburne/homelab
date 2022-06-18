#!/usr/bin/bash

set -euo pipefail

rm -vrf ~/install.bundle ~/install.tgz
mkdir -vp ~/install.bundle

sudo cp /etc/apt/sources.list ~/install.bundle

cd /

sudo tar czvf ~/install.bundle/firmware.tgz \
  lib/firmware/amd/amd_sev_fam17h_model01h.sbin \

sudo tar czvf ~/install.bundle/configuration.tgz \
  etc/default/grub \
  etc/default/networking \
  etc/dracut.conf.d/20-sev-firmware.conf \
  etc/network/interfaces \
  etc/ssh/sshd_config.d/10-no-passwords.conf \
  etc/sysctl.d/10-disable-ipv6.conf \

sudo tar czvf ~/install.bundle/mok.tgz \
  var/lib/shim-signed/mok

cd ~

tar czvf ~/install.bundle/$USER.tgz \
  .ssh \
  .zshrc \
  .zshenv \
  .p10k.zsh \

cp -v ~/install{,.bundle}/linux-5.10.0-15-sme-amd64.tgz
cp -v ~/install{,.bundle}/ldap.tgz
cp -vR ~/install{,.bundle}/patch
cp -vR ~/install{,.bundle}/scripts

mv -v ~/install{,.old}
mv -v ~/install{.bundle,}
sudo chown $USER:$USER install/*
sudo tar czvf ~/install.tgz install
rm -v -rf ~/install
mv -v ~/install{.old,}

sudo chown $USER:$USER ~/install.tgz
