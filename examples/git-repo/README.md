# git-repo — clone the project on boot, no sync needed

Same Flask app as the [`flask`](../flask/) example, but the box clones the public sample repo on first boot via the `git_repo` field. No `easyenv here sync` step — your code is already there when SSH opens.

## What you'll learn

- How the `git_repo` field on a machine triggers cloud-init to clone on boot
- When to use `git_repo` instead of `easyenv here sync` — and when not to

## Quickstart

```sh
cd examples/git-repo
easyenv here up --wait 6m
easyenv here ssh
```

You're on the box. Look around:

```sh
ls ~/easyenv-cli/examples/git-repo/    # app.py is already here
cd ~/easyenv-cli/examples/git-repo
python3 app.py &
```

`Ctrl-C` to drop back, run `exit` to leave, then forward the port from your laptop:

```sh
easyenv here expose &
curl http://localhost:5000
# → hello from git-repo
```

Tear down:

```sh
easyenv here down --force
```

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
