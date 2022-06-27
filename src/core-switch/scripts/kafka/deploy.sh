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

# update config
sudo sed -i "s/^zookeeper\.connect=localhost:2181$/zookeeper.connect=ak-zoo-infr:2181/" /usr/local/kafka/config/server.properties
sudo sed -i "s/^#listeners=PLAINTEXT:\/\/:9092/listeners=PLAINTEXT:\/\/ak-kafka-infr:9092/" /usr/local/kafka/config/server.properties

sudo tee /lib/systemd/system/zookeeper.service << EOF
[Unit]
Description=Apache Zookeeper server
Documentation=http://zookeeper.apache.org
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
NetworkNamespacePath=/run/netns/ak-zoo
ExecStart=/usr/local/kafka/bin/zookeeper-server-start.sh /usr/local/kafka/config/zookeeper.properties
ExecStop=/usr/local/kafka/bin/zookeeper-server-stop.sh
Restart=on-abnormal
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

sudo tee > /lib/systemd/system/kafka.service << EOF
[Unit]
Description=Apache Kafka Server
Documentation=http://kafka.apache.org/documentation.html
Requires=zookeeper.service

[Service]
Type=simple
Environment="JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64"
NetworkNamespacePath=/run/netns/ak-kafka
ExecStart=/usr/local/kafka/bin/kafka-server-start.sh /usr/local/kafka/config/server.properties
ExecStop=/usr/local/kafka/bin/kafka-server-stop.sh
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
