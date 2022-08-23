#!/usr/bin/bash

if [[ "$DEBUG" == "1" ]]
then
  set -euxo pipefail
else
  set -euo pipefail
fi

echo $(vault kv get -mount=kv -field=value dockerhub_read_token) | \
docker login \
  --username $(vault kv get -mount=kv -field=value dockerhub_username) \
  --password-stdin 
