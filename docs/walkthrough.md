# Walkthrough

Everything below assumes Docker is running and you are in the repo root.

## 1. Generate the lab key pair

```bash
./scripts/setup-keys.sh
```

This creates `ssh/lab_key`, copies the public half to `ssh/authorized_keys` (which both
containers mount read only) and prints the `~/.ssh/config` block you need. The private key is
gitignored, so cloning this repo never gives anyone access to anything.

## 2. Bring up the three hosts

```bash
docker compose up -d --build
```

You get:

| Host | Address | Networks | Exposed to your machine |
|---|---|---|---|
| `bastion` | 172.30.10.10 / 172.30.20.10 | dmz + internal | yes, port 2222 |
| `app01` | 172.30.20.20 | internal only | no |
| `db01` | 172.30.20.30 | internal only | no |

The bastion is the only container with a foot in both networks. That dual homing is the whole
trick: it is the only path between the outside world and the internal subnet.

## 3. Log into the bastion

```bash
ssh -i ssh/lab_key -p 2222 jump@127.0.0.1
```

If you have rebuilt the containers, SSH will refuse to connect with
`Host key for [127.0.0.1]:2222 has changed`. That is correct behaviour, not a bug: a rebuilt
container generates fresh host keys, and from SSH's point of view the machine you trusted has
been replaced. Clear the stale entries and reconnect:

```bash
ssh-keygen -R "[127.0.0.1]:2222"
ssh-keygen -R 172.30.20.20
```

You should get the banner and a shell. Try to become root and you can't, the account is locked.
Try password auth from another terminal and sshd refuses before it even prompts, because
`AuthenticationMethods publickey` is set.

## 4. Reach the app server through the bastion

Do not copy your private key onto the bastion. That is the classic mistake, it turns the jump
host into the most valuable target on the network. Use `ProxyJump` instead, which keeps the key
on your workstation and only forwards the encrypted channel.

With the config block from step 1 in place, the whole thing is:

```bash
ssh lab-app
```

Without a config file it is uglier, because `-i` applies to the destination and not to the jump
host, so the hop needs its own identity:

```bash
ssh -i ssh/lab_key \
    -o ProxyCommand="ssh -i ssh/lab_key -p 2222 -W %h:%p jump@127.0.0.1" \
    deploy@172.30.20.20
```

This is worth knowing before an interview demo goes sideways. `ssh -J bastion -i key target`
looks like it should work and fails with `Permission denied (publickey)` at the first hop, which
sends you off debugging the wrong machine.

Run `ip route` on `app01` and you will see there is no default gateway out. The container can
talk to the database and to the bastion, nothing else.

## 5. Reach MySQL without exposing it

The database has no published port, so `mysql -h 127.0.0.1` from your machine goes nowhere.
Forward a local port through the bastion instead:

```bash
ssh -i ssh/lab_key -p 2222 -L 3307:172.30.20.30:3306 -N jump@127.0.0.1
```

Leave that running and in another terminal:

```bash
mysql -h 127.0.0.1 -P 3307 -u appuser -p inventory
```

Password is `applab` unless you changed it in `.env`. `SELECT * FROM assets;` returns the three
lab hosts. Close the tunnel and the database is unreachable again.

Note what the grants in `db/init.sql` do. The MySQL image creates `appuser@'%'`, which means "from
anywhere", so the init script renames it to `appuser@'172.30.20.%'` and cuts it back to SELECT,
INSERT, UPDATE and DELETE on one schema. Renaming rather than recreating keeps the password that
came from the environment variable.

`MYSQL_ROOT_HOST: localhost` in the compose file is the other half. Without it the image creates
`root@'%'`, and a database whose root account accepts connections from any address is one leaked
password away from being someone else's:

```
mysql> SELECT user, host FROM mysql.user;
+----------+---------------+
| appuser  | 172.30.20.%   |
| readonly | 172.30.20.%   |
| root     | localhost     |
+----------+---------------+
```

Even holding valid credentials, a client outside 172.30.20.0/24 is refused by MySQL itself.
Network isolation and database grants are two independent layers, and you want both.

## 6. Prove the isolation

```bash
./scripts/verify-isolation.sh
```

Nine checks, and five of them are supposed to come back blocked. That is the point of the script,
it asserts that the closed paths are actually closed rather than only testing the happy path.

Two of those checks changed after CI ran them on Linux. The original version asserted that the
host could not reach `172.30.20.20` directly, which passed on Docker Desktop and failed on a
Linux runner: a Docker host can always reach a bridge address it is hosting, `internal` network
or not. The honest assertion is that neither the app nor the database publishes a port, which is
what the script checks now.

The probes use bash's `/dev/tcp` rather than `nc`, because the first version reported "blocked"
on a machine that simply did not have netcat installed. A test that cannot tell "refused" from
"I have no way to check" is worse than no test.

## 7. The same thing on real VMs

Docker networks are convenient but they are not firewall rules. On actual Ubuntu hosts I use
`scripts/ufw-rules.sh`, which applies one of three profiles:

```bash
sudo ADMIN_CIDR=198.51.100.0/24 ./scripts/ufw-rules.sh bastion
sudo ./scripts/ufw-rules.sh app
sudo ./scripts/ufw-rules.sh db
```

The bastion profile uses `ufw limit` rather than `ufw allow`, which rate limits repeated
connection attempts from the same source. The database profile is the strict one: default deny
on outbound too, with only DNS allowed out, so a compromised database host cannot phone home.

Two things worth knowing before you run this on a box you care about:

- `ufw --force reset` wipes existing rules. On a remote server, open a second SSH session first,
  so if you lock yourself out you still have a way in.
- Docker publishes ports by writing directly into iptables, below UFW. A container with
  `ports: ["3306:3306"]` is reachable from outside even when UFW says the port is denied.
  Binding to `127.0.0.1:3306:3306` is the fix, and it is exactly why the database in this lab
  has no `ports` block at all.
