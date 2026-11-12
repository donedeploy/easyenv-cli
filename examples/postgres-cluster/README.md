# postgres-cluster — Postgres primary + 2 streaming replicas

Three Ubuntu boxes. All three install PostgreSQL 16 at boot. The primary additionally installs Ansible. Once everyone's up, an inline-ansible playbook configures streaming replication: the primary accepts replicator connections, and the replicas `pg_basebackup` from it.

## easyenv features used

- **Sibling names**: three boxes that reach each other by title; `cross_connection: true` is kept but no longer needed.
- **Inline-ansible stack** (`runner: ansible` + `playbook:`) attached to each machine — installs Postgres (and Ansible on the primary) at boot.
- **Boot vs. post-up phase split** — boot stacks do local-only work; cross-node configuration runs from the primary after `easyenv here up --wait` returns.
- **`easyenv here sync`** — pushes inventory + playbook to the primary.
- **`easyenv here run --cmd '<cmd>'`** — drives the replication playbook from your laptop.

## Quick start

```sh
cd examples/postgres-cluster

make up
make deploy        # sync + remote-replicate (~1-2 min)
make verify
```

The `verify` output should show two replicas streaming:

```
 client_addr  |   state   | sync_state |  sent_lsn  | replay_lsn
--------------+-----------+------------+------------+------------
 10.x.x.x     | streaming | async      | 0/3000148  | 0/3000148
 10.x.x.y     | streaming | async      | 0/3000148  | 0/3000148
```

Tear down:

```sh
make down
```

## Make targets

Each local target echoes its underlying `easyenv` command before running. Remote targets (prefixed `remote-`) run on `pg-primary` and are normally invoked via `easyenv here run` by the local target — you don't call them directly.

| Target | Underlying commands | What it does |
|--------|---------------------|--------------|
| `make up`       | `easyenv here up --wait 10m`                         | Create + start all three boxes. Each box installs Postgres at boot; primary also installs Ansible. |
| `make sync`     | `easyenv here sync`                                  | rsync the project root (`inventory.ini`, `playbooks/`, `Makefile`) to `~/project` on the primary. |
| `make deploy`   | `easyenv here sync` <br> `easyenv here run --cmd 'make remote-replicate'` | Push files, then on the primary: run `configure-replication.yml` against all three boxes. |
| `make verify`   | `easyenv here run --cmd 'make remote-verify'`        | On the primary: query `pg_stat_replication` to confirm both replicas are streaming. |
| `make ssh`      | `easyenv here ssh`                                   | Open an interactive shell on `pg-primary`. |
| `make down`     | `easyenv here down --force`                          | Stop and delete the workspace. |
| `make remote-replicate` | `cd ~/project && ansible-playbook -i inventory.ini playbooks/configure-replication.yml` | (Remote) full replication setup. Idempotent. |
| `make remote-verify`    | `sudo -u postgres psql -c "SELECT client_addr, state, sync_state, sent_lsn, replay_lsn FROM pg_stat_replication;"` | (Remote) prints replication status. |
| `make remote-status`    | `sudo systemctl status postgresql`               | (Remote) Postgres unit status. |

## How it works

### Two-phase setup

Each replica needs the primary to be reachable on port 5432 *before* it can `pg_basebackup`. Boxes don't come up in lockstep — workspace.yml stacks run as their machine boots, with no synchronization across boxes. Solution: split the work.

**Phase 1 — boot-time install (each box, in parallel)**

Inline-ansible stacks attached to each machine just install Postgres (and Ansible on the primary). No cross-node access:

```yaml
machines:
  - title: pg-primary
    stacks:
      - title: install-postgres-and-ansible
        runner: ansible
        playbook: |
          - hosts: localhost
            become: yes
            tasks:
              - apt: { name: [postgresql-16, ansible, make], state: present }
              - service: { name: postgresql, state: started }
```

**Phase 2 — post-up configuration (primary drives all three)**

After `make up` returns, all three boxes are reachable. `make deploy` runs `easyenv here sync` then `easyenv here run --cmd 'make remote-replicate'`, which on the primary executes `playbooks/configure-replication.yml`. That playbook:

- Edits `postgresql.conf` (`wal_level=replica`, `max_wal_senders=10`, `hot_standby=on`).
- Adds `pg_hba.conf` entries for the replicas.
- Creates the `replicator` role.
- On each replica: waits for primary:5432, stops Postgres, wipes `/var/lib/postgresql/16/main`, runs `pg_basebackup -X stream -R`, starts Postgres.
- Drops a marker file so re-running `make deploy` doesn't re-bootstrap healthy replicas.

The `wait_for: host=pg-primary port=5432 timeout=300` task at the top of the replica play is the peer-wait — it'll loop for up to 5 minutes if the primary is somehow lagging.

### Inventory

`inventory.ini` is a static file keyed off box titles (`pg-primary`, `pg-replica-1`, `pg-replica-2`) — `cross_connection: true` makes those resolvable from the primary.

### Credentials

The `replicator` password is hardcoded in `inventory.ini` for sample simplicity. In a real cluster you'd want a vault-encrypted variable.

## Test the replication

```sh
make ssh   # lands on pg-primary

# create some data
sudo -u postgres psql <<EOF
CREATE TABLE hello (id serial primary key, msg text);
INSERT INTO hello (msg) SELECT 'row ' || i FROM generate_series(1, 100) i;
EOF

# query a replica
ssh easyenv@pg-replica-1 'sudo -u postgres psql -c "SELECT count(*) FROM hello;"'
# → 100
```

## Re-running

The playbook is idempotent — `make deploy` is safe to re-run. Replicas already in `streaming` state stay untouched (the bootstrap marker prevents re-basebackup).

To rebuild a replica from scratch, SSH in and `sudo rm /var/lib/postgresql/.easyenv-replica-bootstrapped`, then `make deploy` again.

## Try this next

- [`kubespray`](../kubespray/) — same multi-box pattern, but Kubespray drives the provisioning instead of an inline ansible play.
- [`docker-compose`](../docker-compose/) — for cases where pre-built containers replace this whole setup.
