#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install nginx

[[ ! -f /etc/ssl/certs/dhparam.pem ]] && sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
if [[ ! -f /usr/local/bin/mkcert ]]
then
  sudo apt-get -y install libnss3-tools
  curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
  chmod +x mkcert-v*-linux-amd64
  sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
  sudo mkcert --install
fi

if [[ ! -d /etc/nginx/ssl ]]
then
  mkdir -p certs
  cd certs

  HOSTNAMES_REQUIRING_CERTIFICATES=(os-ctrl-mgmt $(hostname -f))
  for HOSTNAME in "${HOSTNAMES_REQUIRING_CERTIFICATES[@]}"
  do
    echo ${HOSTNAME}
    [[ -f /etc/nginx/ssl/${HOSTNAME}.pem ]] || sudo mkcert -ecdsa ${HOSTNAME}
  done

  sudo mkdir -p /etc/nginx/ssl
  sudo mv *.pem /etc/nginx/ssl

  cd ..
  rm -rf certs
fi

sudo systemctl stop nginx
sudo systemctl disable nginx

sudo sed -i "s/worker_processes auto/worker_processes 6/" /etc/nginx/nginx.conf

sudo tee /lib/systemd/system/nginx-ctrl.service << EOF
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
NetworkNamespacePath=/run/netns/os-ctrl
Type=forking
PIDFile=/run/nginx-ctrl.pid
ExecStartPre=/usr/sbin/nginx -t -q -c /etc/nginx/ctrl/nginx.conf -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/ctrl/nginx.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/ctrl/nginx.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-ctrl.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

sudo tee /lib/systemd/system/os-api-forwarder.service << EOF
[Unit]
Description=Openstack API Forwarder
After=network-online.target
Requires=nginx-ctrl.service
After=nginx-ctrl.service

[Service]
Type=simple

ExecStart=/usr/bin/socat tcp4-listen:5000,fork,reuseaddr,bind=192.168.50.22 tcp4:os-ctrl-api:5000
User=keystone
Group=keystone
SyslogIdentifier=os-api-forwarder
SuccessExitStatus=143

Restart=on-failure

# Time to wait before forcefully stopped.
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /etc/nginx/ctrl/sites-{enabled,available}
sudo cp -v /etc/nginx{,/ctrl}/nginx.conf
sudo cp -v /etc/nginx{,/ctrl}/uwsgi_params
sudo sed -i "s/sites-enabled/ctrl\/sites-enabled/" /etc/nginx/ctrl/nginx.conf
sudo sed -i "s/nginx\\.pid/nginx-ctrl.pid/" /etc/nginx/ctrl/nginx.conf

sudo systemctl daemon-reload
