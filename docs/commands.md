# Command reference

Every `easyenv` command and flag, grouped by top-level. Run `easyenv <cmd> --help` for the same info inline.

## Global flags

These work on any command:

| Flag             | Type   | Default | Purpose                                   |
|------------------|--------|---------|-------------------------------------------|
| `--output`, `-o` | string | `table` | output format: `table`, `json`, `yaml`    |
| `--account`, `-a`| string | (config)| override the active account UUID         |
| `--quiet`, `-q`  | bool   | false   | suppress non-essential output            |
| `--version`      | bool   |         | print version and exit                    |

## Environment variables

| Variable          | Overrides           |
|-------------------|---------------------|
| `EASYENV_SERVER`  | API endpoint        |
| `EASYENV_TOKEN`   | service token       |
| `EASYENV_ACCOUNT` | active account UUID |
| `EASYENV_WEB_URL` | web console URL     |

See [`install.md`](install.md#environment-variables-ci--scripting) for context.

---

## `easyenv auth`

Manage the service token used by the CLI.

| Subcommand | Purpose                                              | Flags         |
|------------|------------------------------------------------------|---------------|
| `login`    | Save a service token to the config file              | `--token`, `--server` |
| `logout`   | Remove the saved token                               |               |
| `whoami`   | Print the user the token belongs to                  |               |
| `token`    | Print the current service token (for scripts/curl)   |               |

## `easyenv config`

Inspect and edit the CLI config.

| Subcommand          | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `view`              | Print the effective config (with env-var overrides applied)    |
| `set <key> <value>` | Set a config value (`server`, `default_account`, `output`, `watch_interval`, `web_url`) |
| `unset <key>`       | Clear a config value                                           |
| `path`              | Print the absolute path of the config file                     |

## `easyenv account`

Multi-tenant: a single token may grant access to several accounts.

| Subcommand          | Purpose                                                |
|---------------------|--------------------------------------------------------|
| `list` (alias `ls`) | List accounts the user belongs to                      |
| `use <uuid\|name>`  | Set the active account (persisted as `default_account`)|
| `current`           | Print the active account UUID                          |

## `easyenv workspace` (aliases `ws`, `w`)

Workspaces are the unit of provisioning — one or more machines created from a YAML spec.

| Subcommand                  | Purpose                                          | Flags |
|-----------------------------|--------------------------------------------------|-------|
| `list` (alias `ls`)         | List workspaces                                  | `--status`, `--search`, `--shared`, `--sort`, `--limit`, `--page` |
| `get <ws>` (alias `describe`)| Describe a workspace by UUID                    |       |
| `create`                    | Create a workspace from a YAML spec, template, or single recipe | `--file`/`-f`, `--template`, `--base`, `--name`, `--ttl`, `--dry-run` |
| `delete <ws>` (alias `rm`)  | Soft-delete a workspace                          | `--force` |
| `start <ws>`                | Start a workspace (async)                        |       |
| `stop <ws>`                 | Stop a workspace                                 |       |
| `restart <ws>`              | Stop then start                                  |       |
| `extend <ws>`               | Extend a workspace's TTL                         | `--duration` (e.g. `1h`, `30m`) |
| `duplicate <ws>`            | Clone a workspace                                | `--title` |
| `watch <ws>`                | Stream workspace + machine + stack status        | `--interval` (default `2s`) |

`workspace create` accepts a YAML spec (`-f`), a template shortcut (`--template`), or a single-recipe shortcut (`--base`). The three modes are mutually exclusive.

```sh
# From a YAML spec
easyenv ws create -f .easyenv/workspace.yml

# From a template (looks up by UUID, falling back to exact title match)
easyenv workspace create \
  --template python_devenv \
  --name review-pr-1284 \
  --ttl 8h

# From a single recipe (one-machine workspace)
easyenv workspace create \
  --base ubuntu \
  --name scratch \
  --ttl 2h
```

`--ttl` accepts `30s`, `5m`, `2h`, etc. (a bare integer is read as seconds). `--name` overrides the workspace title (default: the template's or recipe's title). Add `--dry-run` to validate and print the resolved request body without sending it, handy for CI:

```sh
easyenv ws create -f .easyenv/workspace.yml --dry-run
```

## `easyenv machine` (alias `m`)

Operations on individual machines (boxes) inside a workspace. Most commands require `--workspace`/`-w`.

| Subcommand                  | Purpose                                            | Flags |
|-----------------------------|----------------------------------------------------|-------|
| `list` (alias `ls`)         | List machines in a workspace                       | `-w` (required) |
| `get <m>` (alias `describe`)| Describe a machine                                 | `-w` (required) |
| `delete <m>` (alias `rm`)   | Delete a machine                                   | `-w` (required), `--force` |
| `start <m>`                 | Start a machine                                    | `-w` (required) |
| `stop <m>`                  | Stop a machine                                     | `-w` (required) |
| `restart <m>`               | Stop then start                                    | `-w` (required) |
| `extend <m>`                | Extend a machine's TTL                             | `-w` (required), `--duration` |
| `ssh <m>`                   | Open an interactive SSH session                    | `-w` (required), `--dry-run` |
| `exec <m> -- <cmd…>`        | Run a command, return the remote exit code         | `-w` (required), `--tty`/`-t` |

## `easyenv recipe`

Recipes are OS / pre-baked machine templates (Ubuntu 24.04 LTS, Python Dev Env, Kubernetes Cluster, …). You reference them by title in `workspace.yml`.

| Subcommand          | Purpose                              | Flags                |
|---------------------|--------------------------------------|----------------------|
| `list` (alias `ls`) | List recipes                         | `--search`, `--type` |
| `get <name\|uuid>`  | Describe a recipe                    |                      |

## `easyenv stack`

Catalog stack recipes (`docker-run`, `docker-compose`, `bash`, `argocd`, …) — bundled scripts you compose on top of a recipe via `workspace.yml`.

| Subcommand          | Purpose                                            | Flags          |
|---------------------|----------------------------------------------------|----------------|
| `list` (alias `ls`) | List catalog stack recipes                         |                |
| `get <name\|uuid>`  | Describe a stack recipe (vars schema, defaults)    |                |
| `instances`         | List stack instances on a workspace                | `-w` (required)|

## `easyenv template`

Pre-defined workspace templates — one-shot ways to spin up an environment without writing YAML.

| Subcommand          | Purpose                                | Flags     |
|---------------------|----------------------------------------|-----------|
| `list` (alias `ls`) | List templates                         |           |
| `get <uuid>`        | Describe a template                    |           |
| `use <uuid>`        | Create a workspace from a template     | `--title` |

## `easyenv storage`

Per-account file storage (recipes, shared files, artifacts).

| Subcommand                   | Purpose                                          | Flags             |
|------------------------------|--------------------------------------------------|-------------------|
| `list` (alias `ls`)          | List storage files                               | `--type`          |
| `upload <file>`              | Upload a file                                    | `--name`, `--type` (default `shared_file`) |
| `download <uuid>`            | Download a file via its presigned URL            | `--output`/`-O` (`-` for stdout) |
| `delete <uuid>` (alias `rm`) | Delete a storage file                            |                   |
| `quota`                      | Show storage usage and limit                     |                   |

## `easyenv here`

The day-to-day UX. The CLI walks up from your current directory looking for `.easyenv/workspace.yml`; everything under `here` operates on the workspace named by that file's `metadata.title`.

| Subcommand | Purpose                                                                      | Flags |
|------------|------------------------------------------------------------------------------|-------|
| `up`       | Create or reuse the workspace, then start it                                 | `--title`, `--wait <duration>` |
| `down`     | Stop and delete the workspace                                                | `--title`, `--force` |
| `ssh`      | Interactive shell on the first machine (auto-VPN)                            |       |
| `sync`     | rsync the project tree to `~/<repo-basename>` on the remote                  | `--exclude` (repeatable), `--delete`, `--dry-run` |
| `run`      | sync + run a command on the remote (default: `make run`)                     | `--cmd` |
| `expose`   | Forward all `spec.machines[0].ports[]` from `workspace.yml` to localhost     |       |

`up` is idempotent — if a workspace with the same `metadata.title` already exists in your account, it's reused. Pass `--wait 10m` (or any duration) to block until the workspace becomes `active` before returning.

`sync` defaults to excluding `.git`, `node_modules`, `__pycache__`, `*.pyc`, `.venv`, `venv`, `.env`. Pass `--exclude PATTERN` to add more.

`run` cd's into the project directory on the remote, then executes `--cmd`. If a `.env.dev` file exists alongside `workspace.yml`, it's copied to `.env` (only if `.env` is missing) before `--cmd` runs.

`expose` reads an unofficial `ports[]` annotation on the first machine — see [`workspace-yml.md`](workspace-yml.md#unofficial-ports-annotation).

## `easyenv status`

Server reachability + active account summary. Useful when something feels off.

## `easyenv diagnose`

Deep connectivity diagnostic for a workspace/machine. Flags: `--workspace`/`-w`, `--machine`/`-m`. (Some sub-checks are still being filled in.)

## `easyenv completion`

Generate shell completion scripts:

```sh
easyenv completion bash > /etc/bash_completion.d/easyenv
easyenv completion zsh  > ~/.zsh/completions/_easyenv
easyenv completion fish > ~/.config/fish/completions/easyenv.fish
```

## `easyenv --version`

There's no separate `version` subcommand — the root flag prints `easyenv version <semver> (commit <sha>, built <timestamp>)`.

```sh
easyenv --version
# → easyenv version 0.1.0 (commit abc1234, built 2026-05-02T11:55:00Z)
```
