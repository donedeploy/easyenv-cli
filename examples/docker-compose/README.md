# docker-compose — bring up a compose file with the `docker-compose` stack

One Ubuntu box runs Redis + Redis Commander defined in a compose script. Open the Commander UI in your browser and click around the keys.

## What you'll learn

- How to feed a complete compose file to a stack via a `vars` value
- How port forwarding works for a service published by Docker

## Quickstart

```sh
cd examples/docker-compose
easyenv here up --wait 6m
easyenv here expose &
```

Open <http://localhost:8081> in your browser — Redis Commander loads, and you can poke at the empty `local` connection.

To populate it:

```sh
easyenv here ssh
docker exec -it $(docker ps --filter ancestor=redis:7-alpine -q) redis-cli
> SET hello world
> KEYS *
```

Refresh the Commander UI — your key shows up.

Tear down:

```sh
easyenv here down --force
```

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
