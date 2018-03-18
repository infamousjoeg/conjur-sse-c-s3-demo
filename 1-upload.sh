#!/bin/bash
set -eo pipefail

api_key=$(docker-compose exec conjur sudo -u conjur conjur-plugin-service possum rails r "print Credentials['demo:user:admin'].api_key" | tail -1)

echo '--------- Load Conjur Policy ------------'
output=$(docker-compose run --rm -e CONJUR_AUTHN_API_KEY=$api_key --entrypoint /bin/bash conjur-cli -c "
  cp /src/certs/ca.crt /usr/local/share/ca-certificates/ca.crt
  update-ca-certificates
  conjur policy load --replace root /src/policies/aws-sse-c-policy.yml
  conjur list
  conjur variable values add aws-s3/aes256_key @/src/certs/aes256.key
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