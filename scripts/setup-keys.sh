#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY="$ROOT/ssh/lab_key"

if [ -f "$KEY" ]; then
    echo "key already exists at $KEY"
else
    ssh-keygen -t ed25519 -f "$KEY" -N "" -C "bastion-lab" >/dev/null
    echo "generated $KEY"
fi

cp "$KEY.pub" "$ROOT/ssh/authorized_keys"
chmod 600 "$KEY" "$ROOT/ssh/authorized_keys"

cat <<CFG

Add this to your ~/.ssh/config (adjust the IdentityFile path):

Host lab-bastion
    HostName 127.0.0.1
    Port 2222
    User jump
    IdentityFile $KEY
    IdentitiesOnly yes

Host lab-app
    HostName 172.30.20.20
    User deploy
    IdentityFile $KEY
    IdentitiesOnly yes
    ProxyJump lab-bastion
CFG
