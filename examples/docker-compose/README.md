# docker-compose — bring up a compose file with the `docker-compose` stack

One Ubuntu box runs Redis + Redis Commander defined in a compose script. Open the Commander UI in your browser and click around the keys.

## easyenv features used

- **`docker-compose` catalog stack** — full compose file passed via `vars.script`; the stack drops it on the box and runs `docker compose up -d`. Schema visible with `easyenv stack get docker-compose`.
- **`ports[]` annotation** + **`easyenv here expose`** — forwards Docker-published ports to localhost.

## Quick start

```sh
cd examples/docker-compose
make up
make expose &
```

Open <http://localhost:8081> in your browser — Redis Commander loads, and you can poke at the empty `local` connection.

To populate it:

```sh
make ssh
docker exec -it $(docker ps --filter ancestor=redis:7-alpine -q) redis-cli
> SET hello world
> KEYS *
```

Refresh the Commander UI — your key shows up.

Tear down:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 6m` | Create + start the workspace. The `docker-compose` stack runs `docker compose up -d` during boot. |
| `make deploy` | (alias for `make up`)       | No post-boot work — the stack does everything during `up`. |
| `make expose` | `easyenv here expose`       | Forward the workspace's `ports[]` (here: 8081) to localhost. |
| `make ssh`    | `easyenv here ssh`          | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force` | Stop and delete the workspace. |

## How it works

```yaml
stacks:
  - recipe: docker-compose
    vars:
      script: |
        services:
          redis:
            image: redis:7-alpine
          commander:
            ...
```

The `docker-compose` stack writes the script to disk and runs `docker compose up -d`. Docker and the Compose plugin are installed automatically if not present. Run `easyenv stack get docker-compose` for the full vars schema.

## Edit the compose

Change `.easyenv/workspace.yml` — add services, change versions, expose more ports — then `easyenv here up` again. The stack re-applies and re-runs `docker compose up -d`, which reconciles only what's changed.

## Try this next

- [`airflow`](../airflow/) — same stack, much bigger compose file. Real-world example.
- [`flask`](../flask/) — drop down to writing your own bash with an inline stack.
