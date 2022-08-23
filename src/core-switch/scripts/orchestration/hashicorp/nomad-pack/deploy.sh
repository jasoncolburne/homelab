#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

cd ~
if [[ ! -d /usr/local/go ]] || [[ "${FETCH_GO:-0}" == "1" ]]
then
  rm -f go1.19.linux-amd64.tar.gz
  wget https://go.dev/dl/go1.19.linux-amd64.tar.gz
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.19.linux-amd64.tar.gz
fi

if (! rg local/go/bin ~/.zshrc)
then 
  echo "export PATH='\$PATH:/usr/local/go/bin:/home/${USER}/go/bin:/home/${USER}/src/nomad-pack/bin'" >> ~/.zshrc
  . ~/.zshrc
fi

cd ~/src
rm -rf nomad-pack
git clone https://github.com/hashicorp/nomad-pack
# this step seems to consume all memory on my 256GB server with current library versions
# so we'll disable it
sed -i "s/@golangci-lint/# @golangci-lint/" nomad-pack/GNUmakefile
cd nomad-pack && make dev
