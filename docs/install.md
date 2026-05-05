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

You should see something like `easyenv version 0.1.0 (commit abc1234, built 2025-...)`.

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

## Updating

There is no built-in self-update yet, re-run the install one-liner above. The binary is a single static file; replacing it in place is safe.
