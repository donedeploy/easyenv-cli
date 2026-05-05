# airflow — Apache Airflow on docker-compose

A real-world `docker-compose` stack: Airflow 2.10.5 with LocalExecutor + Postgres, behind port 8080. A sample DAG (`dags/hello_dag.py`) gets synced from your laptop into the box's DAG folder; the scheduler picks it up automatically.

## What you'll learn

- A non-trivial `docker-compose` stack — what a real compose file looks like inside `vars.script`
- Combining a prep stack (inline-bash) + a service stack (catalog) in the same workspace
- Pushing assets onto a running stack via `easyenv here sync`

## Quick start

```sh
cd examples/airflow
easyenv here up --wait 12m       # ~10 min — Airflow image is large
easyenv here sync                # push dags/hello_dag.py
easyenv here expose &
```

Open <http://localhost:8080> — log in with `airflow` / `airflow`. You'll see `hello_easyenv` in the DAG list (it may take a minute for the scheduler to pick it up after sync).

Trigger it manually with the play button, or wait for the daily schedule.

Tear down:

```sh
easyenv here down --force
```

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
easyenv here sync     # the scheduler picks up changes within ~30s
```

The Airflow UI's **Browse → DAG Code** view shows the file as Airflow sees it — handy for confirming the sync worked.

## Why so much memory?

`ram_mb: 8192` looks heavy, but Airflow + Postgres + the Python image add up quickly. If you drop below 4 GB you'll see the scheduler get OOM-killed during DAG parse.

## Try this next

- [`docker-compose`](../docker-compose/) — the same stack with a much smaller compose file.
- [`postgres-cluster`](../postgres-cluster/) — drop one level down: a real Postgres setup without a docker wrapper.
