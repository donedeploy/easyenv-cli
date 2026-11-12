# Install

The `easyenv` CLI is distributed as a static binary on GitHub Releases. Pick your platform below.

## Linux

```sh
# Detect latest version
VERSION=$(curl -fsSL https://api.github.com/repos/donedeploy/easyenv-cli/releases/latest \
  | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')

# amd64
sudo curl -fsSL -o /usr/local/bin/easyenv \
  "https://github.com/donedeploy/easyenv-cli/releases/download/${VERSION}/easyenv_${VERSION}_linux_amd64"
sudo chmod +x /usr/local/bin/easyenv

# arm64
sudo curl -fsSL -o /usr/local/bin/easyenv \
  "https://github.com/donedeploy/easyenv-cli/releases/download/${VERSION}/easyenv_${VERSION}_linux_arm64"
sudo chmod +x /usr/local/bin/easyenv
```

## macOS

```sh
VERSION=$(curl -fsSL https://api.github.com/repos/donedeploy/easyenv-cli/releases/latest \
  | grep -oE '"tag_name":\s*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')

# Apple Silicon (arm64)
sudo curl -fsSL -o /usr/local/bin/easyenv \
  "https://github.com/donedeploy/easyenv-cli/releases/download/${VERSION}/easyenv_${VERSION}_darwin_arm64"
sudo chmod +x /usr/local/bin/easyenv

# Intel (amd64)
sudo curl -fsSL -o /usr/local/bin/easyenv \
  "https://github.com/donedeploy/easyenv-cli/releases/download/${VERSION}/easyenv_${VERSION}_darwin_amd64"
sudo chmod +x /usr/local/bin/easyenv
```

## Windows

Download the latest `easyenv_<version>_windows_amd64.exe` from the [releases page](https://github.com/donedeploy/easyenv-cli/releases/latest), rename it to `easyenv.exe`, and put it somewhere on your `PATH` (for example `%USERPROFILE%\bin\` after adding that directory to `PATH`).

## Verify

```sh
easyenv --version
```

You should see something like `easyenv version 0.6.0 (commit 5972e90…, built 2026-11-12T…)`.

## Authentication

The CLI talks to easyenv.io with a service token.

1. Go to [easyenv.io](https://easyenv.io), open your account settings, and create a service token.
2. Save it locally:

   ```sh
   easyenv auth login --token <paste-here>
   ```

   This writes `~/.config/easyenv/config.yaml` with mode `0600`.

3. Pick the account you want to use (you may belong to several):

   ```sh
   easyenv account list
   easyenv account use <name-or-uuid>
   ```

4. Confirm:

   ```sh
   easyenv auth whoami
   easyenv account current
   ```

## Environment variables (CI / scripting)

Every config value can be overridden via env vars, handy in CI where you don't want to write a config file.

| Variable          | Overrides           | Default                    |
|-------------------|---------------------|----------------------------|
| `EASYENV_SERVER`  | API endpoint        | `https://api.easyenv.io`   |
| `EASYENV_TOKEN`   | service token       | (read from config.yaml)    |
| `EASYENV_ACCOUNT` | active account UUID | (read from config.yaml)    |
| `EASYENV_WEB_URL` | web console URL     | derived from `server`      |

So a CI job needs zero config files, just set those three:

```sh
EASYENV_TOKEN=xxx EASYENV_ACCOUNT=yyy easyenv ws list
```

## Config file

Path: `$XDG_CONFIG_HOME/easyenv/config.yaml`, default `~/.config/easyenv/config.yaml`. Mode `0600` (token is a long-lived credential, keep it tight).

```yaml
server: https://api.easyenv.io
service_token: ey...
default_account: <uuid>
output: table          # table | json | yaml
watch_interval: 2s     # poll interval for `easyenv ws watch`
```

Settings can be edited with `easyenv config set <key> <value>` / `easyenv config unset <key>`, or by editing the file directly. `easyenv config view` prints the effective config (with env-var overrides applied), and `easyenv config path` prints the absolute file path.

## What else the CLI needs

- **OpenSSH 8.4 or newer** (`ssh -V`). Machines are reached through the EasyEnv connection broker, which the box dials outwards, so there is no VPN to install and no port to open. The CLI hands ssh a `ProxyCommand` and, when a box uses a password, answers ssh's password prompt itself. `sshpass` is no longer needed; it is still used if it is installed.
- **rsync** for `machine sync` and `here sync`. `machine cp`, `exec`, `ssh` and `port-forward` do not need it.
- Optional: an ssh key on your EasyEnv profile. With one, boxes accept your key and no password is involved at all.

`easyenv diagnose <machine>` walks the path to a box (backend, grant, broker, port 22, sshd) and stops at the first hop that fails.

## Updating

Re-run the install one-liner above; the binary is a single static file and replacing it in place is safe. Once a day the CLI checks the latest release and prints a one-line notice on stderr when a newer one is out. It never checks for a `dev` build, in CI (`CI` set), or with `EASYENV_NO_UPDATE_CHECK=1`.

> Upgrading from 0.5.0 or older is required, not optional: those versions reach machines through the NetBird mesh, which was removed in September 2026. They still log in and list workspaces, but `ssh`, `exec`, `sync` and `port-forward` fail with `no machine in this workspace has a VPN key`.
