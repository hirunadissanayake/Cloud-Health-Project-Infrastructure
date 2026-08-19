#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl jq nodejs npm "$JAVA_PACKAGE"
sudo npm install --global pm2@latest

curl --fail --silent --show-error \
  https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh \
  --output /tmp/add-google-cloud-ops-agent-repo.sh
sudo bash /tmp/add-google-cloud-ops-agent-repo.sh --also-install

java -version
node --version
pm2 --version
