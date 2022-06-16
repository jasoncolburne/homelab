#!/usr/bin/bash

set -euo pipefail

echo "removing cd-rom from apt sources"
sudo cp ~/install/sources.list /etc/apt/
echo "upgrading operating system"
sudo apt update
sudo apt upgrade
echo "installing required packages"
sudo apt-get -y install \
  bridge-utils \
  clevis-tpm2 \
  clevis-luks \
  clevis-dracut

echo "installing optional packages - you will need to enter your password to switch to zsh"
sudo apt-get -y install zsh git ripgrep && chsh -s $(which zsh) || true

echo "removing open-iscsi"
sudo apt-get -y remove open-iscsi
sudo apt-get -y autoremove

echo "deploying user config for $USER"
cd ~
tar xzvf ~/install/$USER.tgz
echo "grabbing powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

echo "bringing down networking"
sudo systemctl stop networking

cd /
echo "deploying system configuration"
sudo tar xzvf ~/install/configuration.tgz
echo "deploying sev firmware"
sudo tar xzvf ~/install/firmware.tgz

echo "bringing up networking"
sudo systemctl start networking

echo "installing sme kernel"
cd ~
tar xzvf ~/install/5.10.0-14-sme-amd64.tgz
cd 5.10.0-14-sme-amd64
sudo apt install ./linux-image-sme-amd64_5.10.113-1_amd64.deb ./linux-image-5.10.0-14-sme-amd64_5.10.113-1_amd64.deb
cd ~
rm -rf 5.10.0-14-sme-amd64

sudo grub-set-default 'Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux 5.10.0-14-sme-amd64'
sudo update-grub

echo "to complete provisioning phase 1, reboot now."
