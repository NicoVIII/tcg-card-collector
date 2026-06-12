#!/bin/bash
set -euo pipefail

sudo apt-get update

# Install apt repository for modern Erlang/OTP releases.
sudo apt-get install -y curl gnupg apt-transport-https
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" \
  | sudo gpg --dearmor \
  | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/rabbitmq.list <<'EOF'
## Modern Erlang/OTP releases
##
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-erlang/ubuntu/noble noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb2.rabbitmq.com/rabbitmq-erlang/ubuntu/noble noble main
EOF

sudo apt-get -y update
sudo apt-get install -y erlang erlang-dev rebar3 shellcheck sqlite3
sh ./scripts/install_dbmate.sh

echo "Post-create provisioning completed"
