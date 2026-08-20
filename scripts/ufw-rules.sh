#!/usr/bin/env bash
set -euo pipefail

ADMIN_CIDR="${ADMIN_CIDR:-203.0.113.0/24}"
BASTION_IP="${BASTION_IP:-172.30.10.10}"
SSH_PORT="${SSH_PORT:-22}"

if [ "$(id -u)" -ne 0 ]; then
    echo "run this as root on the target VM" >&2
    exit 1
fi

case "${1:-bastion}" in
bastion)
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw limit from "$ADMIN_CIDR" to any port "$SSH_PORT" proto tcp comment 'ssh from admin network only'
    ufw --force enable
    ;;
app)
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow from "$BASTION_IP" to any port 22 proto tcp comment 'ssh from bastion only'
    ufw allow from "$BASTION_IP" to any port 80 proto tcp comment 'http from bastion only'
    ufw --force enable
    ;;
db)
    ufw --force reset
    ufw default deny incoming
    ufw default deny outgoing
    ufw allow out 53 comment 'dns'
    ufw allow from 172.30.20.20 to any port 3306 proto tcp comment 'mysql from app only'
    ufw allow from "$BASTION_IP" to any port 22 proto tcp comment 'ssh from bastion only'
    ufw --force enable
    ;;
*)
    echo "usage: $0 {bastion|app|db}" >&2
    exit 2
    ;;
esac

ufw status numbered
