#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get update
sudo apt-get -y install \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

sudo mkdir -p /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.gpg ]]
then
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list
fi

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << EOF
{
  "bip": "10.1.0.1/16"
}
EOF

sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo iptables -I DOCKER-USER -j ACCEPT

sudo tee /etc/iptables.up.rules << EOF
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ACCEPT
COMMIT
EOF

sudo tee /etc/network/if-pre-up.d/iptables << EOF
#!/bin/sh
/sbin/iptables-restore < /etc/iptables.up.rules
EOF
sudo chmod +x /etc/network/if-pre-up.d/iptables

sudo sysctl fs.inotify.max_user_watches=65536
sudo sysctl fs.inotify.max_user_instances=512

sudo tee /etc/sysctl.d/25-inotify.conf << EOF
fs.inotify.max_user_watches = 65536
fs.inotify.max_user_instances = 512
EOF
