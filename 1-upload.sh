#!/bin/bash
set -eo pipefail

echo
echo '--------- Create Host Factory Token ------------'
echo

api_key=$(docker-compose exec conjur sudo -u conjur conjur-plugin-service possum rails r "print Credentials['demo:user:admin'].api_key" | tail -1)

$output=$(docker exec -e CONJUR_AUTHN_API_KEY=$api_key conjur-cli /bin/bash -c "
  conjur hostfactory tokens create --duration-minutes 30 aws-sse-c/s3-workers_factory  | jq -r '.[0].token'
")

hf_token=$(echo "$output" | tail -1 | tr -d '\r')

echo
echo '--------- Run Ansible on S3-Uploader ------------'
echo

summon docker-compose run --rm --name s3-uploader --env-file @SUMMONENVFILE ansible bash -c "
  ansible-galaxy install cyberark.conjur-host-identity
  ansible-galaxy install ssilab.aws-cli
  HFTOKEN=$hf_token ansible-playbook -i \"localhost,\" -c local /src/playbooks/s3-sse-c-upload.yml
"

# summon --yaml 'SSH_KEY: !var:file ansible/staging/foo/ssh_private_key' bash -c 'ansible-playbook --private-key $SSH_KEY playbook/applications/foo.yml'