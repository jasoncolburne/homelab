#!/usr/bin/bash

set -euo pipefail

echo "removing cd-rom from apt sources"
sudo cp ~/install/sources.list /etc/apt/
echo "upgrading operating system"
sudo apt update
sudo apt upgrade
echo "installing required packages"
sudo apt-get -y install \
  unzip \
  net-tools \
  bridge-utils \
  clevis-tpm2 \
  clevis-luks \
  clevis-dracut

# echo "installing optional packages"
# sudo apt-get -y install zsh git ripgrep && chsh -s $(which zsh) || true

echo "removing open-iscsi"
sudo apt-get -y remove open-iscsi
sudo apt-get -y autoremove

# echo "patching /etc/sysctl.conf to disable ipv6 and reserve keystone's admin port"
# sudo patch -i /etc/sysctl.conf < ~/install/patch/sysctl.conf.patch

echo "deploying user config for $USER"
cd ~
unzip install/ssh.zip

echo "deploying system config"
cd /

echo "bringing down networking"
sudo systemctl stop networking
echo "installing amd firmware"
sudo unzip ~/install/amd.zip
echo "deploying new networking configuration"
sudo unzip -o ~/install/networking.zip
echo "deploying new sshd configuration"
sudo unzip -o ~/install/sshd.zip
echo "deploying new grub configuration"
sudo unzip -o ~/install/grub.zip
echo "bringing up networking"
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

echo "to complete provisioning, reboot now."
