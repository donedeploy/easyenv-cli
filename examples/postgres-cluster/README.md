# postgres-cluster — Postgres primary + 2 streaming replicas

Three Ubuntu boxes. All three install PostgreSQL 16 at boot. The primary additionally installs Ansible. Once everyone's up, an inline-ansible playbook configures streaming replication: the primary accepts replicator connections, and the replicas `pg_basebackup` from it.

## What you'll learn

- Inline-**ansible** stacks (`runner: ansible` + `playbook:`)
- The boot-vs-post-up split for cross-node setup — install at boot, configure when peers are ready
- Driving an Ansible playbook on the primary via `easyenv here run`

## Quickstart

```sh
cd examples/postgres-cluster

easyenv here up --wait 10m
easyenv here sync
easyenv here run --cmd 'make replicate'   # ~1-2 min
easyenv here run --cmd 'make verify'
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
easyenv here down --force
```

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

After `easyenv here up --wait 10m` returns, all three boxes are reachable. `make replicate` runs `playbooks/configure-replication.yml` from the primary, which:

- Edits `postgresql.conf` (`wal_level=replica`, `max_wal_senders=10`, `hot_standby=on`).
- Adds `pg_hba.conf` entries for the replicas.
- Creates the `replicator` role.
- On each replica: waits for primary:5432, stops Postgres, wipes `/var/lib/postgresql/16/main`, runs `pg_basebackup -X stream -R`, starts Postgres.
- Drops a marker file so re-running `make replicate` doesn't re-bootstrap healthy replicas.

The `wait_for: host=pg-primary port=5432 timeout=300` task at the top of the replica play is the peer-wait — it'll loop for up to 5 minutes if the primary is somehow lagging.

### Inventory

`inventory.ini` is a static file keyed off box titles (`pg-primary`, `pg-replica-1`, `pg-replica-2`) — `cross_connection: true` makes those resolvable from the primary.

### Credentials

The `replicator` password is hardcoded in `inventory.ini` for sample simplicity. In a real cluster you'd want a vault-encrypted variable.

## Test the replication

```sh
easyenv here ssh   # lands on pg-primary

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

The playbook is idempotent — `make replicate` is safe to re-run. Replicas already in `streaming` state stay untouched (the bootstrap marker prevents re-basebackup).

To rebuild a replica from scratch, SSH in and `sudo rm /var/lib/postgresql/.easyenv-replica-bootstrapped`, then `make replicate` again.

## Try this next

- [`kubespray`](../kubespray/) — same multi-box pattern, but Kubespray drives the provisioning instead of an inline ansible play.
- [`docker-compose`](../docker-compose/) — for cases where pre-built containers replace this whole setup.
