#!/bin/bash
set -eo pipefail

echo
echo '--------- Installing Docker Community Edition (CE) -----------'
echo

curl -fsSL http://get.docker.com -o get-docker.sh && ./get-docker.sh
usermod -aG docker $USERNAME
newgrp docker

echo
echo '--------- Installing Docker Compose -----------'
echo

curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose