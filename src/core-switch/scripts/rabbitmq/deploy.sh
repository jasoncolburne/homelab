#!/usr/bin/bash
# https://www.rabbitmq.com/install-debian.html

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install curl gnupg apt-transport-https

## Team RabbitMQ's main signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null
## Launchpad PPA that provides modern Erlang releases
curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg > /dev/null
## PackageCloud RabbitMQ repository
curl -1sLf "https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/io.packagecloud.rabbitmq.gpg > /dev/null

## Add apt repositories maintained by Team RabbitMQ
sudo tee /etc/apt/sources.list.d/rabbitmq.list << EOF
## Provides modern Erlang/OTP releases
##
## "bionic" as distribution name should work for any reasonably recent Ubuntu or Debian release.
## See the release to distribution mapping table in RabbitMQ doc guides to learn more.
deb [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu bionic main
deb-src [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu bionic main

## Provides RabbitMQ
##
## "bionic" as distribution name should work for any reasonably recent Ubuntu or Debian release.
## See the release to distribution mapping table in RabbitMQ doc guides to learn more.
deb [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ bionic main
deb-src [signed-by=/usr/share/keyrings/io.packagecloud.rabbitmq.gpg] https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ bionic main
EOF

## Update package indices
sudo apt-get update -y

## Install Erlang packages
sudo apt-get install -y erlang-base \
                        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
                        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
                        erlang-runtime-tools erlang-snmp erlang-ssl \
                        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl

## Install rabbitmq-server and its dependencies
sudo apt-get install rabbitmq-server -y --fix-missing
sudo systemctl disable rabbitmq-server
sudo systemctl stop rabbitmq-server

sudo rabbitmq-plugins enable rabbitmq_amqp1_0

NODE_IP_ADDRESS=$(rg amqp-infr /etc/hosts | cut -d " " -f1)

sudo tee /etc/rabbitmq/rabbitmq-env.conf << EOF
# Defaults to rabbit. This can be useful if you want to run more than one node
# per machine - RABBITMQ_NODENAME should be unique per erlang-node-and-machine
# combination. See the clustering on a single machine guide for details:
# http://www.rabbitmq.com/clustering.html#single-machine
#NODENAME=rabbit

# By default RabbitMQ will bind to all interfaces, on IPv4 and IPv6 if
# available. Set this if you only want to bind to one network interface or#
# address family.
NODE_IP_ADDRESS=${NODE_IP_ADDRESS}

# Defaults to 5672.
#NODE_PORT=5672
EOF

sudo tee /lib/systemd/system/epmd.service << EOF
[Unit]
Description=Erlang Port Mapper Daemon
After=network.target
Requires=epmd.socket

[Service]
NetworkNamespacePath=/run/netns/amqp
ExecStart=/usr/bin/epmd -systemd
Type=simple
StandardOutput=journal
StandardError=journal
User=epmd
Group=epmd

[Install]
Also=epmd.socket
WantedBy=multi-user.target
EOF

sudo tee /lib/systemd/system/rabbitmq-server.service << EOF
# systemd unit example
[Unit]
Description=RabbitMQ broker
After=network.target epmd@0.0.0.0.socket
Wants=network.target epmd@0.0.0.0.socket

[Service]
Type=notify
User=rabbitmq
Group=rabbitmq
UMask=0027
NotifyAccess=all
TimeoutStartSec=600
NetworkNamespacePath=/run/netns/amqp

# To override LimitNOFILE, create the following file:
#
# /etc/systemd/system/rabbitmq-server.service.d/limits.conf
#
# with the following content:
#
# [Service]
# LimitNOFILE=65536

LimitNOFILE=32768

# The following setting will automatically restart RabbitMQ
# in the event of a failure. systemd service restarts are not a
# replacement for service monitoring. Please see
# https://www.rabbitmq.com/monitoring.html
Restart=on-failure
RestartSec=10
WorkingDirectory=/var/lib/rabbitmq
ExecStart=/usr/lib/rabbitmq/bin/rabbitmq-server
ExecStop=/usr/lib/rabbitmq/bin/rabbitmqctl shutdown
# See rabbitmq/rabbitmq-server-release#51
SuccessExitStatus=69

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
