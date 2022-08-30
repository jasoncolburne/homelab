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

# sudo apt-get -y --no-install-recommends install firejail/bullseye-backports

echo "installing optional packages - you will need to enter your user password to switch to zsh"
sudo apt-get -y install zsh git ripgrep && chsh -s $(which zsh) || true

echo "removing open-iscsi"
sudo apt-get -y remove open-iscsi

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
echo "deploying existing MOK"
sudo tar xzvf ~/install/mok.tgz

echo "bringing up networking"
sudo systemctl start networking

echo "installing sme kernel"
cd ~
cp ~/install/kernel.tgz .
~/install/scripts/install-sme-kernel.sh

echo "copying secrets"
cp ~/install/secrets.tgz .

echo "enabling clevis on demand"
sudo systemctl enable clevis-luks-askpass.path

echo "cleaning up"
sudo apt-get -y autoremove

echo "to complete provisioning phase 1, reboot and enable secureboot now."
