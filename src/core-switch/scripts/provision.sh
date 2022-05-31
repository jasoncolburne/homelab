#!/usr/bin/bash

set -euo pipefail

OLD_PWD=$(pwd)

echo "removing cd-rom from apt sources"
sudo cp ~/install/sources.list /etc/apt/
echo "upgrading operating system"
sudo apt update
sudo apt upgrade
echo "installing required packages"
sudo apt -y install \
  unzip \
  net-tools \
  bridge-utils \
# clevis-tpm2 clevis-luks clevis-dracut

echo "installing optional packages"
sudo apt -y install zsh git ripgrep && chsh -s $(which zsh) || true

echo

echo "deploying user config for $USER"
cd ~
unzip install/ssh.zip

echo "deploying system config"
cd /

sudo systemctl stop networking
echo "installing amd firmware"
sudo unzip ~/install/amd.zip
echo "deploying new networking configuration"
sudo unzip -o ~/install/networking.zip
echo "deploying new sshd configuration"
sudo unzip -o ~/install/sshd.zip
echo "deploying new grub configuration"
sudo unzip -o ~/install/grub.zip
sudo systemctl start networking
echo "updating boot images"
sudo update-initramfs -c -k all
echo "updating grub"
sudo update-grub

echo "installing sme kernel"
cd ~
unzip install/kernel.zip
cd 5.10.0-14-sme-amd64
sudo apt install ./linux-image-sme-amd64_5.10.113-1_amd64.deb ./linux-image-5.10.0-14-sme-amd64_5.10.113-1_amd64.deb

cd ~
rm -rf 5.10.0-14-sme-amd64

echo "disabling iscsi"
sudo systemctl --now disable iscsid.service

echo "to complete provisioning, reboot now."

cd $OLD_PWD
