#!/usr/bin/bash

set -euo pipefail

rm -rf ~/install.bundle ~/install.tgz
mkdir -p ~/install.bundle

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

cd ~

tar czvf ~/install.bundle/$USER.tgz \
  .ssh \
  .zshrc \
  .zshenv \
  .p10k.zsh \

cp ~/install{,.bundle}/5.10.0-14-sme-amd64.tgz
cp ~/install{,.bundle}/ldap.tgz
cp -R ~/install{,.bundle}/patch
cp -R ~/install{,.bundle}/scripts

mv ~/install{,.old}
mv ~/install{.bundle,}
sudo tar czvf ~/install.tgz install
rm -rf ~/install
mv ~/install{.old,}

sudo chown $USER:$USER ~/install.tgz
