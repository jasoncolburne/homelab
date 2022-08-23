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
  opt/nomad/docker.json

sudo tar czvf ~/install.bundle/mok.tgz \
  var/lib/shim-signed/mok

cd ~

tar czvf ~/install.bundle/$USER.tgz \
  .docker/config.json \
  .ssh \
  .zshrc \
  .zshenv \
  .p10k.zsh \

cp -v ~{,/install.bundle}/secrets.tgz
cp -v ~{,/install.bundle}/kernel.tgz
cp -v ~/install{,.bundle}/ldap.tgz
cp -vR ~/install{,.bundle}/patch
cp -vR ~/install{,.bundle}/scripts

mv -v ~/install{,.old}
mv -v ~/install{.bundle,}
sudo chown -R $USER:$USER install/*
sudo tar czvf ~/install.tgz install
rm -v -rf ~/install
mv -v ~/install{.old,}

sudo chown $USER:$USER ~/install.tgz
