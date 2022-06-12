#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo ~/install/scripts/openstack/yoga/dependencies/common.sh
[[ -f ~/install/scripts/openstack/yoga/dependencies/$SERVICE-compute.sh ]] && sudo ~/install/scripts/openstack/yoga/dependencies/$SERVICE-compute.sh

sudo bash -c "cat > /lib/systemd/system/nova-compute.service" << EOF
[Unit]
Description=Openstack Compute Compute Node
After=network.target

[Service]
Environment=REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ExecStart=/var/lib/nova/venv/bin/nova-compute
User=nova
Group=nova
WorkingDirectory=/var/lib/nova

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart nova-compute
sudo systemctl enable nova-compute