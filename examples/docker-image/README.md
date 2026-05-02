# docker-image — pull and run a container with the `docker-run` stack

One Ubuntu box. The `docker-run` catalog stack handles installing Docker, pulling `nginx:latest`, and starting it on port 80. You don't write any provisioning code.

## What you'll learn

- How to attach a catalog stack to a recipe
- How `easyenv here expose` reads the `ports[]` annotation to forward localhost
- How to swap the image (it's just a `vars` value)

## Quickstart

```sh
cd examples/docker-image
easyenv here up --wait 5m
easyenv here expose &
curl -s http://localhost:80 | grep -i welcome
```

You should see nginx's welcome page HTML.

`Ctrl-C` the `expose` background job, then:

```sh
easyenv here down --force
```

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
