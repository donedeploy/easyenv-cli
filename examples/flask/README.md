# flask — Flask hello world via inline-bash + `here sync`

One Python Dev Env box. An inline-bash stack installs Flask at boot. Your `app.py` lives locally and is pushed to the box with `easyenv here sync` — edit, sync, restart, repeat.

## What you'll learn

- The shape of an **inline** stack (`runner: bash` + `script:`)
- The `easyenv here sync` workflow — push local files to the remote
- How `easyenv here run` cd's into the project dir and runs `make run` for you

## Quickstart

```sh
cd examples/flask
easyenv here up --wait 6m
easyenv here sync          # push app.py + Makefile
easyenv here run &         # runs `make run` on the remote
easyenv here expose &      # forward localhost:5000

curl http://localhost:5000
# → hello easyenv
```

`Ctrl-C` the background jobs, then:

```sh
easyenv here down --force
```

## How it works

The `workspace.yml` does two things:

1. Picks the **Python Dev Env** recipe (Python 3 already installed, plus a few niceties).
2. Attaches an inline-bash stack that runs `pip install flask` at boot.

```yaml
stacks:
  - title: install-flask
    runner: bash
    script: |
      pip install --break-system-packages flask
```

After `here up`, the box has Python and Flask but no app code yet — that's what `here sync` is for. `easyenv here sync` rsyncs the project root (the directory containing `.easyenv/`) to `~/project` on the box. Then `easyenv here run` SSH's in, cd's to `~/project`, and runs `make run` (which runs `python3 app.py`).

## The `here sync` workflow

This is the day-to-day loop:

```sh
# edit app.py locally in your editor
easyenv here sync          # push the change
easyenv here run &         # restart Flask on the box
```

Excludes are sensible by default: `.git`, `node_modules`, `__pycache__`, `*.pyc`, `.venv`, `venv`, `.env`. Pass `--exclude PATTERN` to add more, or `--delete` to mirror exactly.

## Try this next

- [`git-repo`](../git-repo/) — same Flask app, but the box clones it from GitHub on boot. No `here sync` needed.
- [`docker-compose`](../docker-compose/) — let a stack do the work instead of writing your own.
