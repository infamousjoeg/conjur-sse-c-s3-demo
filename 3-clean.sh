#!/bin/bash
set -eo pipefail

echo
echo '-------------- Bringing Down Conjur Master ---------------'
echo

docker-compose down --remove-orphans

echo
echo '-------------- Removing Orphaned Artifacts ---------------'
echo

echo 'Removing certificates...'
rm -rf ./certs

echo 'Removing Playbook Retries...'
rm -f ./playbooks/*.retry

echo 'Removing Downloaded S3 Objects...'
rm -f ./assets/downloads/*.pdf

echo
echo '-------------- Workspace Clean ---------------'
echo