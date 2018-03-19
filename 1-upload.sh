#!/bin/bash
set -eo pipefail

api_key=$(docker-compose exec conjur sudo -u conjur conjur-plugin-service possum rails r "print Credentials['demo:user:admin'].api_key" | tail -1)

echo '--------- Load Conjur Policy ------------'
$output=$(docker exec conjur-cli /bin/bash -c "
  conjur hostfactory tokens create --duration-minutes 30 s3-workers_factory  | jq -r '.[0].token'
")

hf_token=$(echo "$output" | tail -1 | tr -d '\r')

echo '--------- Run Ansible ------------'

docker-compose build ansible

summon docker-compose run --rm --name s3-uploader --env-file @SUMMONENVFILE ansible bash -c "
  ansible-galaxy install cyberark.conjur-host-identity
  ansible-galaxy install ssilab.aws-cli
  HFTOKEN=$hf_token ansible-playbook -i \"localhost,\" -c local /src/playbooks/s3-sse-c-upload.yml
"

# summon --yaml 'SSH_KEY: !var:file ansible/staging/foo/ssh_private_key' bash -c 'ansible-playbook --private-key $SSH_KEY playbook/applications/foo.yml'