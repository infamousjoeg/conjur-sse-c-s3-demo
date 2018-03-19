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

docker cp conjur-master:/opt/conjur/etc/ssl/ca.pem ./certs

openssl x509 -in ./certs/ca.pem -inform PEM -out ./certs/ca.crt

echo
echo '--------- Bring Up Conjur CLI ------------'
echo

docker-compose up -d conjur-cli

echo
echo '--------- Load Policy & AES256 Key ------------'
echo

docker exec -it conjur-cli /bin/bash -c "
  cp /src/certs/ca.crt /usr/local/share/ca-certificates/ca.crt
  update-ca-certificates
  conjur policy load --replace root /src/policies/aws-sse-c-policy.yml
  conjur list
  conjur variable values add aws-s3/aes256_key @/src/certs/aes256.key
"

echo
echo "Demo environment ready!"
echo "Please be sure to add AWS Access Key ID & Secret Access Key to Conjur manually."
echo
