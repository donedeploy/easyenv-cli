# flask — Flask hello world via inline-bash + `here sync`

One Python Dev Env box. An inline-bash stack installs Flask at boot. Your `app.py` lives locally and is pushed to the box with `easyenv here sync` — edit, sync, restart, repeat.

## easyenv features used

- **`Python Dev Env` recipe** — Python 3 + pip + venv pre-installed.
- **Inline-bash stack** (`runner: bash` + `script:`) attached to the machine — runs `pip install flask` at boot.
- **`easyenv here sync`** — rsyncs the project root (folder containing `.easyenv/`) to `~/project` on the box. Default excludes for `.git`, `node_modules`, `__pycache__`, etc.
- **`easyenv here run --cmd '<cmd>'`** — execute an arbitrary command inside `~/project` on the box from your laptop.

## Quick start

```sh
cd examples/flask
make up
make sync           # push app.py + Makefile
make run &          # runs `python3 app.py` on the box
make expose &       # forward localhost:5000

curl http://localhost:5000
# → hello easyenv
```

`Ctrl-C` the background jobs, then:

```sh
make down
```

## Make targets

Each local target echoes its underlying `easyenv` command before running. Remote targets (prefixed `remote-`) execute on the box; you don't normally invoke them directly.

| Target | Underlying commands | What it does |
|--------|---------------------|--------------|
| `make up`     | `easyenv here up --wait 6m`                   | Create + start the box. The inline-bash stack `pip install`s Flask during boot. |
| `make sync`   | `easyenv here sync`                           | rsync the project root (this folder) to `~/project` on the box. |
| `make deploy` | `easyenv here sync`                           | Box already has Flask installed at boot, so deploy = sync. |
| `make run`    | `easyenv here run --cmd 'make remote-run'`    | On the box: `python3 app.py` (via the remote target). |
| `make expose` | `easyenv here expose`                         | Forward `ports[5000]` to `localhost:5000`. |
| `make ssh`    | `easyenv here ssh`                            | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force`                   | Stop and delete the workspace. |
| `make remote-run` | `python3 app.py`                          | (Remote-only) starts the Flask app. Invoked by `make run` via `easyenv here run`. |

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

After `make up`, the box has Python and Flask but no app code yet — that's what `make sync` is for. It rsyncs the project root (the directory containing `.easyenv/`) to `~/project` on the box. Then `make run` SSH's in via `easyenv here run --cmd 'make remote-run'` and runs `python3 app.py`.

## The sync workflow

This is the day-to-day loop:

```sh
# edit app.py locally in your editor
make sync     # push the change
make run &    # restart Flask on the box
```

Excludes are sensible by default: `.git`, `node_modules`, `__pycache__`, `*.pyc`, `.venv`, `venv`, `.env`. Pass `--exclude PATTERN` to add more, or `--delete` to mirror exactly.

## Try this next

- [`git-repo`](../git-repo/) — same Flask app, but the box clones it from GitHub on boot. No `here sync` needed.
- [`docker-compose`](../docker-compose/) — let a stack do the work instead of writing your own.
