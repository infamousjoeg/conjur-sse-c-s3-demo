#!/bin/bash
set -eo pipefail

docker-compose down --remove-orphans

rm -rf ./certs