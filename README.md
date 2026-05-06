# easyenv-cli

Official examples and CLI reference for [easyenv.io](https://easyenv.io), the platform for ephemeral, on-demand development environments and technical assessments.

The `easyenv` CLI is how you drive easyenv.io from your terminal: spin workspaces up, push your code, expose ports, tear them down. This repo gives you a place to start.

- [`docs/install.md`](docs/install.md) - install the CLI on macOS / Linux / Windows
- [`docs/commands.md`](docs/commands.md) - every command and flag
- [`docs/workspace-yml.md`](docs/workspace-yml.md) - `.easyenv/workspace.yml` schema reference
- [`docs/stacks.md`](docs/stacks.md) - catalog stack recipes vs inline stacks
- [`examples/`](examples/) - nine ready-to-run sample projects (listed [below](#examples))

## Install

Download a pre-built binary from [github.com/donedeploy/easyenv-cli/releases](https://github.com/donedeploy/easyenv-cli/releases):

```sh
# Linux (amd64)
VERSION=$(curl -fsSL https://api.github.com/repos/donedeploy/easyenv-cli/releases/latest \
  | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
sudo curl -fsSL -o /usr/local/bin/easyenv \
  "https://github.com/donedeploy/easyenv-cli/releases/download/${VERSION}/easyenv_${VERSION}_linux_amd64"
sudo chmod +x /usr/local/bin/easyenv
easyenv --version
```

For macOS, Windows, and arm64, see [`docs/install.md`](docs/install.md).

## First-time setup

1. Mint a service token at [easyenv.io](https://easyenv.io) → **Account** → **Service tokens**.
2. Save it locally:

   ```sh
   easyenv auth login --token <paste-from-easyenv.io>
   ```

3. Pick the account you want to work in:

   ```sh
   easyenv account list
   easyenv account use <name-or-uuid>
   easyenv auth whoami
   ```

Your config lives at `~/.config/easyenv/config.yaml` (mode 0600). All settings can also be overridden via `EASYENV_SERVER`, `EASYENV_TOKEN`, `EASYENV_ACCOUNT` env vars, useful in CI.

## 30-second tour

```sh
git clone https://github.com/donedeploy/easyenv-cli.git
cd easyenv-cli/examples/ubuntu
make up
make ssh
```

You're in. `exit` to drop back, then `make down` to tear it down.

Each example ships a `Makefile` that wraps the underlying `easyenv` commands and echoes them before running, so you can learn the raw form as you go.

## Examples

Each folder under [`examples/`](examples/) is a self-contained workspace — `cd` in, follow the README, and you're up. Roughly ordered from simplest to most involved:

| Lab                                          | Teaches                                                        | Boxes |
|----------------------------------------------|----------------------------------------------------------------|-------|
| [`ubuntu`](examples/ubuntu/)                 | The minimal `workspace.yml` — one Ubuntu box, nothing else.    | 1     |
| [`docker-image`](examples/docker-image/)     | The `docker-run` catalog stack — pull and run any image.       | 1     |
| [`docker-compose`](examples/docker-compose/) | The `docker-compose` catalog stack — bring up a compose file.  | 1     |
| [`flask`](examples/flask/)                   | Inline-bash stacks + the `easyenv here sync` workflow.         | 1     |
| [`git-repo`](examples/git-repo/)             | The `git_repo` field — let cloud-init clone your code on boot. | 1     |
| [`airflow`](examples/airflow/)               | Real-world `docker-compose` stack — Airflow with a sample DAG. | 1     |
| [`kubespray`](examples/kubespray/)           | Multi-box workspace + `cross_connection` + Kubespray.          | 3     |
| [`postgres-cluster`](examples/postgres-cluster/) | Inline-ansible stacks + Postgres streaming replication.    | 3     |
| [`argocd`](examples/argocd/)                 | Catalog stacks composing with the Kubernetes Cluster recipe.   | 3     |

See [`examples/README.md`](examples/README.md) for the standard run loop and cleanup notes.

## Where next

| If you want to…                                       | Read                                       |
|-------------------------------------------------------|--------------------------------------------|
| Install on a different OS / architecture              | [`docs/install.md`](docs/install.md)       |
| See every CLI command + flag                          | [`docs/commands.md`](docs/commands.md)     |
| Author a `.easyenv/workspace.yml` from scratch        | [`docs/workspace-yml.md`](docs/workspace-yml.md) |
| Understand catalog stacks vs inline stacks            | [`docs/stacks.md`](docs/stacks.md)         |
| Try a working sample (Ubuntu, Flask, K8s, Airflow, …) | [`examples/`](examples/)                   |

## Links

- Web app: [easyenv.io](https://easyenv.io)
- Product docs: [easyenv.io/docs](https://easyenv.io/docs)
- Support / feedback: open an issue on this repo
