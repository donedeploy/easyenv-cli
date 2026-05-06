# ubuntu — minimal workspace

The smallest possible `.easyenv/workspace.yml`: one Ubuntu box, no stacks. Showcases the bare-minimum workspace shape and the core `easyenv here` commands.

## easyenv features used

- **Minimal `workspace.yml`** — `apiVersion`, `kind`, `metadata.title`, one machine with a `recipe` and `resources`. Nothing else.
- **`easyenv here up`** — looks the workspace up by `metadata.title` and either creates it or starts the existing one. Idempotent.
- **`easyenv here ssh`** — interactive shell on the first machine.
- **`easyenv here down --force`** — stop and delete the workspace.

## Quick start

```sh
cd examples/ubuntu
make up
make ssh
```

You're now on a fresh Ubuntu 24.04 box. Try:

```sh
lsb_release -a
whoami       # easyenv
hostname     # dev
```

`exit` to disconnect, then tear it down:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running, so you learn the raw form as you go.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 5m`  | Create + start the workspace. Idempotent — re-run to start an existing one. |
| `make deploy` | (alias for `make up`)        | No post-boot work for this lab; provided for consistency with other examples. |
| `make ssh`    | `easyenv here ssh`           | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force`  | Stop and delete the workspace. |

## How it works

Look at [.easyenv/workspace.yml](.easyenv/workspace.yml) — that's the entire spec. Two fields are doing all the work: `metadata.title` (how the CLI looks the workspace up on re-runs) and `spec.machines[0].recipe: "Ubuntu 24.04 LTS"` (which OS image to provision).

`easyenv here up` is idempotent — re-run it and it'll find the existing workspace by title and start it (instead of creating a duplicate).

## Try this next

- [`docker-image`](../docker-image/) — add a stack to pull and run an image automatically.
- [`flask`](../flask/) — install something on top of the box and expose a port.
