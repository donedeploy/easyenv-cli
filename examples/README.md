# Examples

Nine ready-to-run sample projects. Each one is a self-contained workspace — `cd` into the folder, follow the README, and you're up.

## Prereqs

You need the `easyenv` CLI installed and authenticated. If you haven't done that yet, see the [top-level README](../README.md#install) — it takes about a minute.

```sh
easyenv auth whoami      # should print your email
easyenv account current  # should print an account UUID
```

## Recommended order

| Lab                                   | Teaches                                                        | Boxes |
|---------------------------------------|----------------------------------------------------------------|-------|
| [`ubuntu`](ubuntu/)                   | The minimal `workspace.yml` — one Ubuntu box, nothing else.    | 1     |
| [`docker-image`](docker-image/)       | The `docker-run` catalog stack — pull and run any image.       | 1     |
| [`docker-compose`](docker-compose/)   | The `docker-compose` catalog stack — bring up a compose file.  | 1     |
| [`flask`](flask/)                     | Inline-bash stacks + the `easyenv here sync` workflow.         | 1     |
| [`git-repo`](git-repo/)               | The `git_repo` field — let cloud-init clone your code on boot. | 1     |
| [`airflow`](airflow/)                 | Real-world `docker-compose` stack — Airflow with a sample DAG. | 1     |
| [`kubespray`](kubespray/)             | Multi-box workspace + `cross_connection` + Kubespray.          | 3     |
| [`postgres-cluster`](postgres-cluster/) | Inline-ansible stacks + Postgres streaming replication.      | 3     |
| [`argocd`](argocd/)                   | Catalog stacks composing with the Kubernetes Cluster recipe.   | 3     |

## The standard loop

Every lab has a `Makefile` that wraps the underlying `easyenv` commands. The targets are consistent across labs — pick what's relevant:

```sh
cd examples/<lab>
make up        # easyenv here up --wait <N>m   (idempotent — safe to re-run)
make sync      # easyenv here sync             (where applicable)
make deploy    # full provisioning — usually sync + a remote step
make ssh       # easyenv here ssh
make expose    # easyenv here expose
make down      # easyenv here down --force
```

Each `make` target echoes the raw `easyenv` command before running it, so you can copy/paste once you've memorized the shape. The CLI walks up from your current directory to find `.easyenv/workspace.yml`, so you can run anything from anywhere inside the lab folder.

## Cleanup

Workspaces auto-stop after their `duration` expires (set in each `workspace.yml`), but **they aren't deleted automatically**. Always run `make down` at the end, or `easyenv ws list` periodically to catch stragglers.
