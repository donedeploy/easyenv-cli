# ubuntu — basic workspace

The smallest possible `.easyenv/workspace.yml`: one Ubuntu box, no stacks, no fuss. Start here if you've never used easyenv before.

## What you'll learn

- The shape of a `workspace.yml` file
- The four commands you'll use every day: `easyenv here up`, `ssh`, `expose`, `down`

## Quick start

```sh
cd examples/ubuntu
easyenv here up --wait 5m
easyenv here ssh
```

You're now on a fresh Ubuntu 24.04 box. Try:

```sh
lsb_release -a
whoami       # easyenv
hostname     # dev
```

`exit` to disconnect, then tear it down:

```sh
easyenv here down --force
```

## How it works

Look at [.easyenv/workspace.yml](.easyenv/workspace.yml) — that's the entire spec. Two fields are doing all the work: `metadata.title` (how the CLI looks the workspace up on re-runs) and `spec.machines[0].recipe: "Ubuntu 24.04 LTS"` (which OS image to provision).

`easyenv here up` is idempotent — re-run it and it'll find the existing workspace by title and start it (instead of creating a duplicate).

## Try this next

- [`docker-image`](../docker-image/) — add a stack to pull and run an image automatically.
- [`flask`](../flask/) — install something on top of the box and expose a port.
