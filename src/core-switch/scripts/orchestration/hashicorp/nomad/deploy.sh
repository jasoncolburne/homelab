#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

sudo apt-get -y install nomad

sudo usermod -G docker -a nomad

sudo tee /etc/nomad.d/nomad.hcl << EOF
# Full configuration options can be found at https://www.nomadproject.io/docs/configuration

data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"

ui {
  enabled = false
}

server {
  # license_path is required as of Nomad v1.1.1+
  #license_path = "/opt/nomad/license.hclic"
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled = true
  servers = ["127.0.0.1"]
}

consul {
  address = "127.0.0.1:8500"
  token = "CONSUL_TOKEN"
}

vault {
  enabled = true
  address = "https://127.0.0.1:8200"
  token = "VAULT_TOKEN"
  create_from_role = "nomad-cluster"
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }

    auth {
      config = "/opt/nomad/docker.json"
    }
  }
}
EOF