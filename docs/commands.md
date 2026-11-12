# Command reference

Every `easyenv` command and flag, grouped by top-level. Run `easyenv <cmd> --help` for the same info inline.

## Global flags

These work on any command:

| Flag             | Type   | Default | Purpose                                   |
|------------------|--------|---------|-------------------------------------------|
| `--output`, `-o` | string | `table` | output format: `table`, `json`, `yaml`    |
| `--account`, `-a`| string | (config)| override the active account UUID         |
| `--quiet`, `-q`  | bool   | false   | suppress non-essential output            |
| `--version`, `-v`| bool   |         | print version and exit                    |

## Environment variables

| Variable          | Overrides           |
|-------------------|---------------------|
| `EASYENV_SERVER`  | API endpoint        |
| `EASYENV_TOKEN`   | service token       |
| `EASYENV_ACCOUNT` | active account UUID |
| `EASYENV_WEB_URL` | web console URL     |
| `EASYENV_NO_UPDATE_CHECK` | set to anything: no daily check for a newer release (also off when `CI` is set) |

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

Workspaces are the unit of provisioning: one or more machines created from a YAML spec, a template or a single recipe.

| Subcommand                  | Purpose                                          | Flags |
|-----------------------------|--------------------------------------------------|-------|
| `list` (alias `ls`)         | List workspaces (every page unless `--limit`/`--page`) | `--status`, `--search`, `--shared`, `--sort` (`name_asc`, `name_desc`, `status_active`), `--limit` (max 200), `--page` |
| `get <ws>` (alias `describe`)| Describe a workspace, with the commands for each machine |  |
| `create`                    | Create a workspace from a YAML spec, template, or single recipe | `--file`/`-f`, `--template`, `--base`, `--name`, `--ttl`, `--public-ip`, `--wait`, `--dry-run` |
| `delete <ws>` (alias `rm`)  | Delete a workspace                               | `--force` |
| `start <ws>`                | Start a workspace (async)                        |       |
| `stop <ws>`                 | Stop a workspace, and say why it stopped         |       |
| `restart <ws>`              | Stop then start                                  |       |
| `extend <ws>`               | Extend a workspace's TTL                         | `--duration` (`30m`, `2h`, `1d`) |
| `duplicate <ws>`            | Clone a workspace                                | `--title` |
| `watch <ws>`                | Stream workspace + machine + stack status        | `--interval` (default `2s`) |
| `members <ws>`              | List the workspace's members                     |       |

`workspace connect` and `disconnect` are kept for old scripts and do nothing: there is no VPN to bring up (see [Reaching machines](#reaching-machines)).

`workspace create` accepts a YAML spec (`-f`), a template (`--template`), or a single recipe (`--base`). The three are mutually exclusive. `--template` and `--base` look the reference up by UUID first, then by exact title.

```sh
# From a YAML spec
easyenv ws create -f .easyenv/workspace.yml --wait

# From a template (easyenv template list)
easyenv workspace create \
  --template python-dev-single \
  --name review-pr-1284 \
  --ttl 8h --wait

# From a single recipe (easyenv recipe list)
easyenv workspace create \
  --base ubuntu_24_04 \
  --name scratch \
  --ttl 2h --wait

# A box with a public IPv4, reachable by plain ssh without the CLI
easyenv workspace create --base ubuntu_24_04 --public-ip --name my-box
```

A new workspace is `not_started`. **`--wait` starts it** and blocks until every machine is active, then prints how to reach each one. Without `--wait`, start it yourself with `easyenv ws start <ws>`.

`--ttl` takes minutes, hours or days: `30m`, `2h`, `1d`. Seconds and bare numbers are refused, because the API has no such unit. `--name` overrides the workspace title (default: the template's or recipe's title). `--dry-run` validates and prints the resolved request body without sending it, handy in CI:

```sh
easyenv ws create -f .easyenv/workspace.yml --dry-run
```

## `easyenv machine` (alias `m`)

Operations on individual machines (boxes). `--workspace`/`-w` is optional wherever it says so: the machine is found among the workspaces you can see.

| Subcommand                  | Purpose                                            | Flags |
|-----------------------------|----------------------------------------------------|-------|
| `list` (alias `ls`)         | List machines in a workspace                       | `-w` |
| `get <m>` (alias `describe`)| Describe a machine                                 | `-w` |
| `start <m>` / `stop <m>` / `restart <m>` | Lifecycle                            | `-w` |
| `extend <m>`                | Extend a machine's TTL                             | `-w`, `--duration` (`30m`, `2h`, `1d`) |
| `ssh <m>`                   | Interactive shell                                  | `-w` (optional), `--dry-run` (print the ssh command) |
| `exec <m> -- <cmd…>`        | Run a command, exit with the remote exit code      | `-w` (optional), `--tty`/`-t` |
| `cp <src> <dst>`            | Copy one file or dir; one side is `M:/path`        | `-w` (optional) |
| `sync <src> <dst>`          | rsync; one side is `M:/path`                       | `-w` (optional), `--exclude` (repeatable), `--delete`, `--dry-run` |
| `port-forward <m> <spec…>` (aliases `forward`, `pf`) | Forward `PORT` or `LOCAL:REMOTE` to localhost until Ctrl-C | `-w` (optional), `--no-ssh` (one port, no ssh client) |
| `logs <m>`                  | The box's bootstrap, status and cloud-init logs    | `-w` (optional), `--follow`/`-f`, `--source <path>` |
| `password <m>`              | Print the machine's password                       | `-w` |
| `hostname <m>`              | Print the name for your ssh config (`<uuid>.box.easyenv.io`) |  |
| `proxy <m>`                 | stdin/stdout to a port inside the machine, for ssh's `ProxyCommand` | `--port` (default 22) |
| `vm-id <m>`                 | Print the underlying VM id                         | `-w` |

```sh
easyenv machine exec QN9noelw -- 'systemctl is-active nginx'
easyenv machine cp ./fixtures.sql QN9noelw:/tmp/
easyenv machine sync ./src QN9noelw:/home/easyenv/app --exclude node_modules
easyenv machine port-forward QN9noelw 8080 5433:5432
easyenv machine logs QN9noelw -f
```

To remove one machine, use the web console; `machine delete` explains why it does not do it from here. Delete the whole workspace with `easyenv ws delete`.

### Reaching machines

Every command above reaches the box through the **EasyEnv connection broker**: the box keeps a connection open outwards, and the CLI asks the backend for a short-lived grant for that one box. There is no VPN, no mesh, no DNS and no open port, so there is nothing to connect first. You need OpenSSH 8.4+ and, for `sync`, rsync.

Boxes take an ssh key from your EasyEnv profile, or their own password. The CLI fetches the password and answers ssh's prompt itself, so `sshpass` is not needed.

When a machine will not answer:

```sh
easyenv diagnose QN9noelw
# ok    auth       you@example.com
# ok    grant      wss://broker.easyenv.io/v1/attach/QN9noelw, expires in 4m59s
# ok    broker     agent connected, attach took 266ms
# ok    port 22    open in 64ms
# ok    sshd       SSH-2.0-OpenSSH_9.6p1
```

### Your own ssh client

`machine proxy` is an OpenSSH `ProxyCommand`, so plain `ssh`, `scp`, `rsync`, `sftp` and VS Code Remote-SSH all work:

```
# ~/.ssh/config
Host *.box.easyenv.io
  User easyenv
  ProxyCommand easyenv machine proxy %n
```

```sh
ssh QN9noelw.box.easyenv.io
```

Use `%n`, not `%h`: OpenSSH lowercases `%h`, and machine ids are mixed case. Your own client signs in with the key on your profile or the password from `easyenv machine password <m>`.

## `easyenv recipe`

Recipes are OS / pre-baked machine templates (Ubuntu 24.04 LTS, Python Dev Env, Kubernetes Cluster, …). You reference them by title in `workspace.yml`.

| Subcommand          | Purpose                              | Flags                |
|---------------------|--------------------------------------|----------------------|
| `list` (alias `ls`) | List recipes                         | `--search`, `--type` |
| `get <name\|uuid>`  | Describe a recipe                    |                      |

## `easyenv stack`

Catalog stack recipes (`docker-run`, `docker-compose`, `bash`, `argocd`, …) are bundled scripts you compose on top of a recipe, in `workspace.yml` or onto a running workspace.

| Subcommand          | Purpose                                            | Flags          |
|---------------------|----------------------------------------------------|----------------|
| `list` (alias `ls`) | List catalog stack recipes                         |                |
| `get <name\|uuid>`  | Describe a stack recipe (vars schema, defaults)    |                |
| `instances`         | List stack instances on a workspace                | `-w` |
| `add`               | Attach a catalog or inline stack to a workspace    | `-w`, `-m` (one machine), `--recipe` + `--var k=v`, or `--inline-title` + `--inline-runner bash\|ansible` + `--inline-file` |
| `apply <instance>`  | Run a stack instance now; prints what was queued, skipped or blocked | `-w`, `-m` (one machine) |
| `logs <instance>`   | A stack instance's output                          | `-w` |
| `remove <instance>` (alias `rm`) | Remove a stack instance               | `-w`, `--force` |

```sh
easyenv stack add -w <ws> --recipe docker-run --var image=nginx:latest
easyenv stack add -w <ws> -m <m> --inline-title bootstrap --inline-runner bash --inline-file ./bootstrap.sh
```

## `easyenv template`

Pre-defined workspace templates — one-shot ways to spin up an environment without writing YAML.

| Subcommand          | Purpose                                | Flags     |
|---------------------|----------------------------------------|-----------|
| `list` (alias `ls`) | List templates                         |           |
| `get <uuid\|title>` | Describe a template                    |           |
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
| `ssh`      | Interactive shell on the first machine                                       |       |
| `sync`     | rsync the project tree to `~/<repo-basename>` on the remote                  | `--exclude` (repeatable), `--delete`, `--dry-run` |
| `run`      | sync + run a command on the remote (default: `make run`)                     | `--cmd` |
| `expose`   | Forward all `spec.machines[0].ports[]` from `workspace.yml` to localhost     |       |
| `watch`    | Stream the workspace's status until Ctrl-C                                   | `--interval` |

`up` is idempotent — if a workspace with the same `metadata.title` already exists in your account, it's reused. Pass `--wait 10m` (or any duration) to block until the workspace becomes `active` before returning.

`sync` defaults to excluding `.git`, `node_modules`, `__pycache__`, `*.pyc`, `.venv`, `venv`, `.env`. Pass `--exclude PATTERN` to add more.

`run` cd's into the project directory on the remote, then executes `--cmd`. If a `.env.dev` file exists alongside `workspace.yml`, it's copied to `.env` (only if `.env` is missing) before `--cmd` runs.

`expose` reads an unofficial `ports[]` annotation on the first machine — see [`workspace-yml.md`](workspace-yml.md#unofficial-ports-annotation).

## `easyenv status`

Server reachability + active account summary. Useful when something feels off.

## `easyenv diagnose`

`easyenv diagnose <m>` walks the path to a machine (backend, grant, broker, port 22, sshd) and stops at the first hop that fails. Flags: `--workspace`/`-w` (optional), `--port` (default 22). See [Reaching machines](#reaching-machines).

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
# → easyenv version 0.6.0 (commit 5972e90…, built 2026-11-12T…)
```

Once a day the CLI also checks the latest release and, when a newer one is out, prints one line on stderr after the command. It stays quiet for `dev` builds, with `--quiet`, in CI, and with `EASYENV_NO_UPDATE_CHECK` set.
