#!/usr/bin/env bash
set -uo pipefail

pass=0
fail=0

tcp_from_host() {
    timeout 2 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
}

tcp_from_container() {
    docker exec "$1" bash -c "timeout 2 bash -c 'exec 3<>/dev/tcp/$2/$3'" >/dev/null 2>&1
}

publishes_a_port() {
    [ -n "$(docker port "$1" 2>/dev/null)" ]
}

check() {
    local description="$1" expected="$2" result
    shift 2

    if "$@"; then result="reachable"; else result="blocked"; fi

    if [ "$result" = "$expected" ]; then
        printf '  [ ok ]   %-50s %s\n' "$description" "$result"
        pass=$((pass + 1))
    else
        printf '  [FAIL]   %-50s %s, expected %s\n' "$description" "$result" "$expected"
        fail=$((fail + 1))
    fi
}

require_containers() {
    local container
    for container in lab-bastion lab-app lab-db; do
        if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
            printf 'container %s is not running, start the lab first\n' "$container" >&2
            exit 1
        fi
    done
}

wait_for_mysql() {
    local waited=0
    while [ "$waited" -lt 90 ]; do
        if docker exec lab-db mysqladmin ping -h 127.0.0.1 --silent >/dev/null 2>&1; then
            return 0
        fi
        sleep 3
        waited=$((waited + 3))
    done
    printf 'mysql never became ready, checks against it will be misleading\n' >&2
    return 1
}

require_containers
printf 'waiting for mysql to finish initialising\n'
wait_for_mysql || true

printf '\nnetwork isolation checks\n\n'

check "host    -> bastion ssh, the one published port" reachable \
    tcp_from_host 127.0.0.1 2222

check "host    -> mysql directly" blocked \
    tcp_from_host 127.0.0.1 3306

check "app     publishes no port to the outside" blocked \
    publishes_a_port lab-app

check "db      publishes no port to the outside" blocked \
    publishes_a_port lab-db

check "bastion -> app ssh" reachable \
    tcp_from_container lab-bastion 172.30.20.20 22

check "bastion -> db mysql" reachable \
    tcp_from_container lab-bastion 172.30.20.30 3306

check "app     -> db mysql" reachable \
    tcp_from_container lab-app 172.30.20.30 3306

check "app     -> the internet" blocked \
    tcp_from_container lab-app 1.1.1.1 443

check "db      -> the internet" blocked \
    tcp_from_container lab-db 1.1.1.1 443

printf '\npassed %s, failed %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
