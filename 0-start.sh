#!/bin/bash
set -eo pipefail

echo
echo '--------- Bring Up Conjur ------------'
echo

docker-compose up -d conjur

echo
echo '--------- Configure Conjur ------------'
echo

docker exec conjur-master \
  evoke configure master -h conjur-master -p Cyberark1 demo

mkdir ./certs

docker cp conjur-master:/opt/conjur/etc/ssl/ca.pem ./certs

openssl x509 -in ./certs/ca.pem -inform PEM -out ./certs/ca.crt

echo
echo '--------- Wait for Healthy Conjur Master -----------'
echo

set +e
while : ; do
  printf "..."
  sleep 2
  healthy=$(curl -sk https://$HOSTNAME/health | jq -r '.ok')
  if [[ $healthy == true ]]; then
    break
  fi
done
printf "\n"
set -e

echo
echo '--------- Bring Up Conjur CLI ------------'
echo

docker-compose up -d conjur-cli

echo
echo '--------- Load Policy & Generate/Load AES256 Key ------------'
echo

docker exec conjur-cli /bin/bash -c "
  cp /src/certs/ca.crt /usr/local/share/ca-certificates/ca.crt
  update-ca-certificates
  conjur policy load --as-group security_admin /src/policies/aws-sse-c-policy.yml
  conjur list
  conjur variable values add aws-sse-c/aws-s3/aes256_key $(openssl rand -hex 16)
"

echo
echo '--------- Build S3-Workers Docker Image ------------'
echo

docker-compose build ansible

echo
echo "Demo environment ready!"
echo "Please be sure to add AWS Access Key ID & Secret Access Key to Conjur manually."
echo
