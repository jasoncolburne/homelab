#!/usr/bin/bash

sudo apt-get -y install build-essential fakeroot devscripts ripgrep
if rg -q 'debian unstable main' /etc/apt/sources.list
then
  echo "found unstable sources, continuing"
else
  echo "did not find unstable sources, patching sources.list"
  sudo sh -c "echo >> /etc/apt/sources.list"
  sudo sh -c "echo 'deb-src http://httpredir.debian.org/debian unstable main' >> /etc/apt/sources.list"
fi
sudo apt-get update
