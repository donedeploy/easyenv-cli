# airflow — Apache Airflow on docker-compose

A real-world `docker-compose` stack: Airflow 2.10.5 with LocalExecutor + Postgres, behind port 8080. A sample DAG (`dags/hello_dag.py`) gets synced from your laptop into the box's DAG folder; the scheduler picks it up automatically.

## easyenv features used

- **Stack composition on one machine** — an inline-bash prep stack (`runner: bash`) followed by the **`docker-compose` catalog stack**. They run in order at boot.
- **`docker-compose` catalog stack with a non-trivial `vars.script`** — full Airflow compose, anchors, healthchecks, init container.
- **`easyenv here sync`** workflow — push DAG files into the running compose stack's bind-mounted directory.
- **`ports[]`** + **`easyenv here expose`** — forwards 8080 to localhost.

## Quick start

```sh
cd examples/airflow
make up                # ~10 min — Airflow image is large
make sync              # push dags/hello_dag.py
make expose &
```

Open <http://localhost:8080> — log in with `airflow` / `airflow`. You'll see `hello_easyenv` in the DAG list (it may take a minute for the scheduler to pick it up after sync).

Trigger it manually with the play button, or wait for the daily schedule.

Tear down:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 12m` | Create + start the box. The `docker-compose` stack pulls Airflow images and starts `webserver`/`scheduler`/`postgres` during boot. |
| `make sync`   | `easyenv here sync`          | rsync the project root (incl. `dags/`) to `~/project` on the box. The bind-mounted DAG dir picks up changes within ~30s. |
| `make deploy` | `make sync` (alias)          | Stacks already provisioned at boot; deploy just pushes the latest DAGs. |
| `make expose` | `easyenv here expose`        | Forward `ports[8080]` to `localhost:8080`. |
| `make ssh`    | `easyenv here ssh`           | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force`  | Stop and delete the workspace. |

## How it works

Two stacks compose together:

1. **`prepare-dags-dir`** (inline bash) — creates `/home/easyenv/project/{dags,logs,plugins}` with the right ownership before docker-compose runs. Without this, the bind mounts would be owned by root and Airflow couldn't write logs.
2. **`docker-compose`** (catalog) — drops the compose script and runs `docker compose up -d`. Brings up Postgres, runs `airflow db migrate` + `users create` in a one-shot init container, then starts the webserver and scheduler.

The DAG dir is bind-mounted into the Airflow containers:

```yaml
volumes:
  - /home/easyenv/project/dags:/opt/airflow/dags
```

`easyenv here sync` rsyncs the project root to `/home/easyenv/project/` on the box (the default when no `git_repo` is set). So `dags/hello_dag.py` lands at `/home/easyenv/project/dags/hello_dag.py`, which the scheduler scans and imports.

## Edit-and-deploy loop

```sh
# edit dags/hello_dag.py locally
make sync     # the scheduler picks up changes within ~30s
```

The Airflow UI's **Browse → DAG Code** view shows the file as Airflow sees it — handy for confirming the sync worked.

## Why so much memory?

`ram_mb: 8192` looks heavy, but Airflow + Postgres + the Python image add up quickly. If you drop below 4 GB you'll see the scheduler get OOM-killed during DAG parse.

## Try this next

- [`docker-compose`](../docker-compose/) — the same stack with a much smaller compose file.
- [`postgres-cluster`](../postgres-cluster/) — drop one level down: a real Postgres setup without a docker wrapper.
