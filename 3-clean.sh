#!/bin/bash
set -eo pipefail

docker-compose down --remove-orphans

rm -f ./certs/ca.pem
rm -f ./certs/ca.crt
