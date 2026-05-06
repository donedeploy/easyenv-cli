# git-repo — clone the project on boot, no sync needed

Same Flask app as the [`flask`](../flask/) example, but the box clones the public sample repo on first boot via the `git_repo` field. No `easyenv here sync` step — your code is already there when SSH opens.

## easyenv features used

- **`git_repo` field on a machine** — cloud-init clones the URL into `~/<repo-basename>` on first boot. Same field also redirects the "remote project dir" used by `easyenv here sync` and `easyenv here run`.
- **`easyenv here expose`** + `ports[]` — forwards the app port to localhost once the app is running.

## Quick start

```sh
cd examples/git-repo
make up
make ssh
```

You're on the box. Look around:

```sh
ls ~/easyenv-cli/examples/git-repo/    # app.py is already here
cd ~/easyenv-cli/examples/git-repo
python3 app.py &
```

`Ctrl-C` to drop back, run `exit` to leave, then forward the port from your laptop:

```sh
make expose &
curl http://localhost:5000
# → hello from git-repo
```

Tear down:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 6m` | Create + start the box. Cloud-init clones the git repo on first boot; the inline stack installs Flask. |
| `make deploy` | (alias for `make up`)       | Code arrives via `git_repo` at boot, so deploy = up. |
| `make expose` | `easyenv here expose`       | Forward `ports[5000]` to localhost. |
| `make ssh`    | `easyenv here ssh`          | Open an interactive shell on the box. |
| `make down`   | `easyenv here down --force` | Stop and delete the workspace. |

## How it works

The only difference from [`flask`](../flask/) is one line:

```yaml
machines:
  - title: app
    recipe: Python Dev Env
    git_repo: https://github.com/donedeploy/easyenv-cli       # ← this
    ...
```

When set, cloud-init clones the URL into `~/<repo-basename>` on first boot. The basename is taken from the URL (with `.git` stripped if present), so this lands at `~/easyenv-cli/`.

The inline `install-flask` stack still runs the same way as before, installing Flask on top of the recipe.

## `git_repo` vs `here sync` — which one?

|                            | `flask` (`here sync`)            | `git-repo` (`git_repo`)            |
|----------------------------|----------------------------------|------------------------------------|
| Where the code lives       | rsync'd from your laptop         | cloned fresh from GitHub on boot   |
| Works on a fork            | yes — any path                   | yes, but you have to push it first |
| Edit-and-test loop         | edit local → `here sync`         | push to GitHub → `here up` again   |
| Best for                   | active development               | demos, CI, ephemeral spin-ups      |
| Needs a public-ish repo?   | no                               | yes (or a deploy-key setup)        |

If you're iterating fast, use `here sync`. If you want one-command spin-ups for demos or CI, use `git_repo`.

## Try this next

- [`flask`](../flask/) — the sync flow, side by side.
- [`airflow`](../airflow/) — `here sync` to push DAGs into a running Airflow.
