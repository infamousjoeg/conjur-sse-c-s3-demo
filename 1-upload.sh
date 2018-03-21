#!/bin/bash
set -eo pipefail

echo
echo '--------- Create Host Factory Token ------------'
echo

output=$(docker exec conjur-master conjur hostfactory tokens create --duration-minutes 1 aws-sse-c/s3-workers_factory  | jq -r '.[0].token')

echo "Time-to-live (TTL) set to 1 minute"
echo $output

hf_token=$(echo "$output" | tail -1 | tr -d '\r')

echo
echo '--------- Run Ansible on S3-Uploader ------------'
echo

AWS_ACCESS_KEY_ID=$(docker exec conjur-master conjur variable value aws-sse-c/aws-iam/access_key_id)
AWS_SECRET_ACCESS_KEY=$(docker exec conjur-master conjur variable value aws-sse-c/aws-iam/secret_access_key)
AWS_DEFAULT_REGION='us-east-1'

docker-compose run --rm --name s3-uploader \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
  -e CONJUR_MAJOR_VERSION=4 \
  s3-worker bash -c "
    echo '192.168.3.10 conjur-master' >> /etc/hosts
    ansible-galaxy install cyberark.conjur-host-identity
    ansible-galaxy install ssilab.aws-cli
    HFTOKEN=$hf_token ansible-playbook -i \"localhost,\" -c local /src/playbooks/s3-sse-c-upload.yml
  "

echo
echo "Uploaded all assets to s3://conjur-sse-c-s3-demo/"
echo

# summon --yaml 'SSH_KEY: !var:file ansible/staging/foo/ssh_private_key' bash -c 'ansible-playbook --private-key $SSH_KEY playbook/applications/foo.yml'