#!/bin/sh
set -e

ssh-keygen -A >/dev/null 2>&1

install -d -m 700 -o deploy -g deploy /home/deploy/.ssh

if [ -f /keys/authorized_keys ]; then
    install -m 600 -o deploy -g deploy /keys/authorized_keys /home/deploy/.ssh/authorized_keys
else
    echo "no /keys/authorized_keys mounted, run scripts/setup-keys.sh first" >&2
fi

exec "$@"
