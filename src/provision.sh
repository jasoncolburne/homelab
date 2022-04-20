#!/usr/bin/sh

# this removes the cd-rom source so the cd doesn't need to be inserted
sudo cp ~/install/sources.list /etc/apt/
sudo apt update
sudo apt upgrade
# required packages
sudo apt -y install unzip net-tools bridge-utils clevis-tpm2 clevis-luks clevis-dracut
# optional packages
sudo apt -y install zsh git ripgrep && chsh -s $(which zsh) || true

# user config
cd ~
unzip install/ssh.zip

# system config
cd /
sudo systemctl stop networking
sudo unzip ~/install/amd.zip
sudo unzip -o ~/install/networking.zip
sudo unzip -o ~/install/sshd.zip
sudo unzip -o ~/install/grub.zip
sudo systemctl start networking
sudo update-initramfs -c -k all
sudo update-grub

cd ~
unzip install/kernel.zip
cd 5.10.0-14-sme-amd64
sudo apt install ./linux-image-sme-amd64_5.10.113-1_amd64.deb ./linux-image-5.10.0-14-sme-amd64_5.10.113-1_amd64.deb

cd ~
rm -rf 5.10.0-14-sme-amd64

sudo reboot
