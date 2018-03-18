#!/bin/bash
set -eo pipefail

docker-compose up -d conjur
docker-compose logs -f conjur

docker-compose exec conjur \
  evoke configure master -h conjur -p Cyberark1 demo

docker cp conjur:/opt/conjur/etc/ssl/ca.pem ./certs
openssl x509 -in ./certs/ca.pem -inform PEM -out ./certs/ca.crt

echo
echo "Demo environment ready!"
echo "Please be sure to add AWS Access Key ID & Secret Access Key to Conjur manually."
echo