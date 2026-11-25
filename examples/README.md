# Examples

Nine ready-to-run sample projects. Each one is a self-contained workspace — `cd` into the folder, follow the README, and you're up.

## Prereqs

To deploy a lab, you need the `easyenv` CLI installed and authenticated. If you haven't done that yet, see the [top-level README](../README.md#install) — it takes about a minute.

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
make expose    # easyenv here expose (labs with forwarded ports)
make down      # easyenv here down --force
```

Each `make` target echoes the raw `easyenv` command before running it, so you can copy/paste once you've memorized the shape. The CLI walks up from your current directory to find `.easyenv/workspace.yml`, so you can run anything from anywhere inside the lab folder.

## Cleanup

Workspaces auto-stop after their `duration` expires (set in each `workspace.yml`), but **they aren't deleted automatically**. Always run `make down` at the end, or `easyenv ws list` periodically to catch stragglers.

## Check the examples

From the repository root, with Python 3.11 or newer, Bash, GNU Make and Docker Compose v2 or newer on your PATH:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install ansible-core Flask jsonschema yamllint
python test/example_test.py
```

The default run checks the workspace fields documented in [the manifest reference](../docs/workspace-yml.md), YAML formatting, local README links, documented port mappings, Make targets, Bash and Ansible syntax, and Compose configuration. It also requests both Flask routes, renders the Kubespray inventory and PostgreSQL access rules, and checks how Kubespray and Airflow handle failed commands. These checks work offline after setup. Docker Compose only reads the configuration.

With an authenticated EasyEnv CLI, add `--catalog` to resolve every manifest using `easyenv ws create --dry-run`. To check a running example, follow its quick start, then supply the ID of its first machine from `easyenv machine list -w WORKSPACE_ID`:

```sh
python test/example_test.py --live postgres-cluster MACHINE_ID
```

Live checks use the guest services directly. For Flask, leave the app running. For Airflow, sync the DAG and wait for the scheduler. For Kubespray and PostgreSQL, finish `make deploy` first. The probes read the state of the running lab.
