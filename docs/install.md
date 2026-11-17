# Install

macOS and Linux:

```sh
curl -fsSL https://get.easyenv.io/cli | sh
```

Windows (PowerShell):

```powershell
irm https://get.easyenv.io/cli.ps1 | iex
```

`get.easyenv.io` redirects to [`install.sh`](../install.sh) and [`install.ps1`](../install.ps1) in this repo, so you can read exactly what runs before you run it.

## What the script does

On macOS and Linux, `install.sh`:

1. picks the build for your machine from `uname`: `darwin` or `linux`, `amd64` (x86_64) or `arm64` (aarch64). Anything else, such as 32-bit `armv7l`, stops with a message rather than installing the wrong file. An x86_64 shell under Rosetta on Apple silicon gets the native arm64 build.
2. downloads `checksums.txt` from the latest release, which names every build of that release, then the binary for your machine from the same release.
3. checks the binary's SHA-256 against `checksums.txt`. A mismatch stops the install and nothing is written.
4. installs it as `easyenv`: over the `easyenv` already on your `PATH` if there is one (that is how an upgrade works), otherwise in `/usr/local/bin`. It uses `sudo` only when that folder is not writable, and falls back to `~/.local/bin` when there is no `sudo`, telling you how to put that folder on your `PATH`.
5. runs `easyenv --version`.

It needs `curl` or `wget`, and `sha256sum`, `shasum` or `openssl` to check the download.

On Windows, `install.ps1` does the same with `easyenv_<version>_windows_amd64.exe`: it checks the SHA-256, installs `easyenv.exe` in `$HOME\bin`, and adds that folder to your user `Path` only when it is not there yet, so running it again does not add it twice. It works in PowerShell 7 and in Windows PowerShell 5.1, and changes the `Path` of the window you ran it in too, so `easyenv` works there right away.

## Settings

| Variable               | What it does                                                        |
|------------------------|---------------------------------------------------------------------|
| `EASYENV_VERSION`      | Install this release instead of the latest, e.g. `0.6.0`.           |
| `EASYENV_INSTALL_DIR`  | macOS and Linux only: install into this folder; no `sudo` is tried. |
| `EASYENV_RELEASES_URL` | A mirror laid out like `https://github.com/donedeploy/easyenv-cli/releases`. |

```sh
curl -fsSL https://get.easyenv.io/cli | EASYENV_VERSION=0.6.0 sh
curl -fsSL https://get.easyenv.io/cli | EASYENV_INSTALL_DIR="$HOME/bin" sh
```

```powershell
$env:EASYENV_VERSION = '0.6.0'; irm https://get.easyenv.io/cli.ps1 | iex
```

## Install by hand

Every [release](https://github.com/donedeploy/easyenv-cli/releases/latest) has a bare binary per platform (`easyenv_<version>_linux_amd64`, `linux_arm64`, `darwin_amd64`, `darwin_arm64`, `windows_amd64.exe`), the same binary in a `.tar.gz` or `.zip`, and `checksums.txt`. Download yours, check it with `sha256sum -c --ignore-missing checksums.txt` (`shasum -a 256` on macOS), make it executable, and put it on your `PATH` as `easyenv` (`easyenv.exe` on Windows).

## Verify

```sh
easyenv --version
```

You should see something like `easyenv version 0.6.1 (commit 5972e90…, built 2026-11-12T…)`.

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
