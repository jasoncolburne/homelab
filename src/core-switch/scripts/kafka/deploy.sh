#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get update
sudo apt-get -y install default-jdk

sudo rm -rf /usr/local/kafka

cd ~
[[ -f kafka_2.13-3.2.0.tgz ]] || wget https://dlcdn.apache.org/kafka/3.2.0/kafka_2.13-3.2.0.tgz
tar xzvf kafka_2.13-3.2.0.tgz
sudo mv kafka_2.13-3.2.0 /usr/local/kafka

sudo bash -c "cat > /etc/systemd/system/zookeeper.service" << EOF
[Unit]
Description=Apache Zookeeper server
Documentation=http://zookeeper.apache.org
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
ExecStart=/usr/local/kafka/bin/zookeeper-server-start.sh /usr/local/kafka/config/zookeeper.properties
ExecStop=/usr/local/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF

sudo bash -c "cat > /etc/systemd/system/kafka.service" << EOF
[Unit]
Description=Apache Kafka Server
Documentation=http://kafka.apache.org/documentation.html
Requires=zookeeper.service

[Service]
Type=simple
Environment="JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64"
ExecStart=/usr/local/kafka/bin/kafka-server-start.sh /usr/local/kafka/config/server.properties
ExecStop=/usr/local/kafka/bin/kafka-server-stop.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
