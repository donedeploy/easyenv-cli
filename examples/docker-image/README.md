# docker-image — pull and run a container with the `docker-run` stack

One Ubuntu box. The `docker-run` catalog stack handles installing Docker, pulling `nginx:latest`, and starting it on port 80. No custom provisioning code.

## easyenv features used

- **`docker-run` catalog stack** — declarative `vars.image:` field; the stack provisions Docker and runs the container at boot. Discoverable via `easyenv stack list` / `easyenv stack get docker-run`.
- **`ports[]` annotation** in `workspace.yml`, consumed by `easyenv here expose` to forward published ports to localhost.
- **`easyenv here expose`** — port-forwards the workspace's `ports[]` over the easyenv tunnel.

## Quick start

```sh
cd examples/docker-image
make up
make expose &
curl -s http://localhost:80 | grep -i welcome
```

You should see nginx's welcome page HTML.

`Ctrl-C` the `expose` background job, then:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 5m` | Create + start the workspace. The `docker-run` stack pulls and starts nginx during boot. |
| `make deploy` | (alias for `make up`)       | No post-boot work — the stack does everything during `up`. |
| `make expose` | `easyenv here expose`       | Forward the workspace's `ports[]` (here: 80) to localhost. |
| `make ssh`    | `easyenv here ssh`          | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force` | Stop and delete the workspace. |

## How it works

```yaml
stacks:
  - recipe: docker-run
    vars:
      image: nginx:latest
```

That's the whole thing. The `docker-run` stack:

1. Installs Docker if it's missing.
2. Logs in to private registries (if `vars.credentials` is set).
3. Pulls `vars.image` plus any extras from `vars.images`.
4. Runs `vars.image` as a container.

Run `easyenv stack get docker-run` to see the full vars schema.

## Swap the image

Edit `.easyenv/workspace.yml` and change `image:` to whatever you want — `redis:7-alpine`, `ghcr.io/your-org/app:tag`, etc. For private registries, add `vars.credentials`:

```yaml
stacks:
  - recipe: docker-run
    vars:
      image: ghcr.io/your-org/app:latest
      credentials: |
        ghcr.io your-username ghp_xxxxxxxxxxxx
```

Then `easyenv here up` again — it's idempotent.

## Try this next

- [`docker-compose`](../docker-compose/) — bring up multiple services with one stack.
- [`flask`](../flask/) — write your own provisioning with an inline-bash stack.
