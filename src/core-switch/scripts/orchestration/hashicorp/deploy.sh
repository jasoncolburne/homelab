#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]; then
  set -euxo pipefail
else
  set -euo pipefail
fi

if [[ ! -f /etc/apt/sources.list.d/hashicorp.list ]]; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
  echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
fi

sudo apt-get update

~/install/scripts/orchestration/hashicorp/consul/deploy.sh
~/install/scripts/orchestration/hashicorp/vault/deploy.sh
~/install/scripts/orchestration/hashicorp/nomad/deploy.sh
~/install/scripts/orchestration/hashicorp/nomad-pack/deploy.sh

sudo apt-get install -y jq

sudo sed -i "s/ENCRYPTION_KEY/$(consul keygen | sed 's/\//\\\//g')/" /etc/consul.d/consul.hcl

sudo systemctl restart consul
sleep 5

sudo sed -i 's/^encrypt/#encrypt/' /etc/consul.d/consul.hcl

if [[ ! -f ~/consul.bootstrap.json ]]; then
  echo 'writing consul bootstrap to ~/.consul.bootstrap.json'
  consul acl bootstrap -format=json > ~/consul.bootstrap.json
fi

export CONSUL_HTTP_TOKEN=$(cat ~/consul.bootstrap.json | jq -r '.SecretID')

POLICY_DIR=~/install/scripts/orchestration/hashicorp/consul/policy

consul acl policy create -name=agent -rules=@${POLICY_DIR}/agent.hcl
AGENT_CONSUL_TOKEN=$(consul acl token create -policy-name=agent -description="consul agent" -format=json | jq -r '.SecretID')
sudo sed -i "s/AGENT_TOKEN/${AGENT_CONSUL_TOKEN}/" /etc/consul.d/consul.hcl
unset AGENT_CONSUL_TOKEN

sudo systemctl restart consul
sleep 5

consul acl policy create -name=list-all-nodes -rules='node_prefix "" { policy = "read" }'
consul acl policy create -name=service-consul-read -rules='service "consul" { policy = "read" }'
consul acl token update -id=00000000-0000-0000-0000-000000000002 -policy-name=list-all-nodes -policy-name=service-consul-read -description="anonymous"

consul acl policy create -name=vault-service -rules=@${POLICY_DIR}/vault-service.hcl
VAULT_CONSUL_TOKEN=$(consul acl token create -policy-name=vault-service -description="vault" -format=json | jq -r '.SecretID')
sudo sed -i "s/CONSUL_TOKEN/${VAULT_CONSUL_TOKEN}/" /etc/vault.d/vault.hcl
unset VAULT_CONSUL_TOKEN

consul acl policy create -name=nomad-server -rules=@${POLICY_DIR}/nomad-server.hcl
consul acl policy create -name=nomad-client -rules=@${POLICY_DIR}/nomad-client.hcl
NOMAD_CONSUL_TOKEN=$(consul acl token create -policy-name=nomad-server -policy-name=nomad-client -description="nomad" -format=json | jq -r '.SecretID')
sudo sed -i "s/CONSUL_TOKEN/${NOMAD_CONSUL_TOKEN}/" /etc/nomad.d/nomad.hcl
unset NOMAD_CONSUL_TOKEN

sudo systemctl start vault
sleep 2
if [[ ! -f ~/.vault.init.json ]]; then
  echo 'writing vault initialization to ~/.vault.init.json'
  vault operator init -key-shares=1 -key-threshold=1 -format=json > ~/.vault.init.json
fi

cat ~/.vault.init.json | jq '.root_token' > ~/.vault-token

sleep 2

if [[ ! vault status ]]; then
  echo "please enter '$(cat ~/.vault.init.json | jq -r '.keys_base64[0]')' at the next prompt."
  vault operator unseal
fi

sleep 2

POLICY_DIR=~/install/scripts/orchestration/hashicorp/vault/policy
vault policy write kv ${POLICY_DIR}/kv-allowed.hcl
vault policy write nomad-server ${POLICY_DIR}/nomad-server-disallowed.hcl
vault write /auth/token/roles/nomad-cluster @${POLICY_DIR}/nomad-cluster-role.json

NOMAD_VAULT_TOKEN=$(vault token create -policy nomad-server -period 72h -orphan -format=json | jq -r '.auth.client_token')
sudo sed -i "s/VAULT_TOKEN/${NOMAD_VAULT_TOKEN}/" /etc/nomad.d/nomad.hcl
unset NOMAD_VAULT_TOKEN
