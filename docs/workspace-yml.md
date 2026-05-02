# `.easyenv/workspace.yml` reference

The `workspace.yml` file is the source of truth for every workspace you create with `easyenv here ...`. The CLI walks up from your current directory looking for `.easyenv/workspace.yml`; the workspace's `metadata.title` becomes its identifier on the server.

## Top-level shape

```yaml
apiVersion: easyenv.io/v1
kind: Workspace
metadata:
  title: <required, becomes the workspace name>
  description: <optional>
spec:
  duration: <int>            # optional, e.g. 4
  duration_unit: <string>    # optional, "minutes" | "hours" | "days"
  cross_connection: <bool>   # optional, default false
  single_active_machine: <bool>  # optional, default false
  virtualization_backend: <string>  # optional, override the account default
  machines:
    - title: <required>
      recipe: <required>
      ...
```

The CLI rejects the file if `apiVersion` isn't `easyenv.io/v1`, `kind` isn't `Workspace`, `metadata.title` is empty, or `spec.machines` has no entries.

## `metadata`

| Field         | Type   | Required | Notes                                       |
|---------------|--------|----------|---------------------------------------------|
| `title`       | string | yes      | Becomes the workspace name. Re-running `easyenv here up` looks workspaces up by this title. |
| `description` | string | no       | Free text shown in the web UI               |

## `spec`

| Field                    | Type    | Notes                                                             |
|--------------------------|---------|-------------------------------------------------------------------|
| `duration`               | int     | Workspace TTL. Pair with `duration_unit`.                         |
| `duration_unit`          | string  | `minutes`, `hours`, or `days`.                                    |
| `cross_connection`       | bool    | Lets machines in this workspace reach each other (NetBird mesh). Required for any multi-box lab where boxes talk to each other. |
| `single_active_machine`  | bool    | Only one machine can be running at a time — saves resources for personal sandboxes. |
| `virtualization_backend` | string  | Override the account's default backend (Proxmox, Docker, …).      |
| `machines`               | list    | One or more entries — see below.                                  |

## `spec.machines[]`

| Field         | Type   | Required | Notes                                                                                                       |
|---------------|--------|----------|-------------------------------------------------------------------------------------------------------------|
| `title`       | string | yes      | Becomes the machine's hostname inside `cross_connection` workspaces.                                       |
| `description` | string | no       |                                                                                                             |
| `recipe`      | string | yes      | The recipe **title**, exactly as shown in `easyenv recipe list`. e.g. `Ubuntu 24.04 LTS`, `Python Dev Env`. |
| `resources`   | object | no       | `cpu`, `ram_mb`, `storage_gb` — see below.                                                                  |
| `git_repo`    | string | no       | URL of a public git repo. Cloud-init clones it to `~/<repo-basename>` on first boot.                       |
| `position`    | int    | no       | Display order. Defaults to the index in the list.                                                          |
| `stacks`      | list   | no       | Stack attachments — see below.                                                                             |
| `ports`       | list   | no       | Unofficial annotation read by `easyenv here expose` — see below.                                            |

### `resources`

```yaml
resources:
  cpu: 2          # vCPUs
  ram_mb: 2048    # RAM in MiB
  storage_gb: 20  # disk in GiB
```

Omit any field to use the recipe's default.

### `stacks[]`

A stack is a piece of configuration applied on top of the recipe. Each entry is **either** a *catalog* reference (`recipe:` set) **or** an *inline* definition (`runner:` + `script:` or `playbook:` + `title:`). The validator rejects entries that mix both or set neither.

**Catalog stack** (resolved against `easyenv stack list`):

```yaml
stacks:
  - recipe: docker-run
    vars:
      image: nginx:latest
```

**Inline bash stack:**

```yaml
stacks:
  - title: install-flask
    runner: bash
    script: |
      pip install --break-system-packages flask
```

**Inline ansible stack:**

```yaml
stacks:
  - title: install-postgres
    runner: ansible
    playbook: |
      - hosts: localhost
        become: yes
        tasks:
          - apt: { name: postgresql-16, state: present, update_cache: yes }
```

| Field      | Type   | Required for | Notes                                                          |
|------------|--------|--------------|----------------------------------------------------------------|
| `recipe`   | string | catalog      | Stack recipe name, e.g. `docker-run`, `docker-compose`.        |
| `vars`     | map    | catalog (opt)| Vars defined by the stack's `vars_schema`.                     |
| `title`    | string | inline       | Display name for this attachment.                              |
| `runner`   | string | inline       | `bash` or `ansible`.                                           |
| `script`   | string | inline-bash  | Body of the bash script.                                       |
| `playbook` | string | inline-ansible | Inline Ansible playbook (list of plays).                     |

### `git_repo`

When set, cloud-init clones the URL into `~/<repo-basename>` on first boot — no `easyenv here sync` needed. The "remote dir" used by `easyenv here sync` and `easyenv here run` is also derived from this field (basename of the URL with `.git` stripped). When unset, the remote dir defaults to `~/project`.

The same workspace.yml works on a fork, but the box clones what's *on GitHub*, not your local edits — useful for ephemeral demos and CI; less useful when you're iterating. See the `git-repo/` example for a side-by-side comparison.

### Unofficial `ports[]` annotation

`easyenv here expose` reads `spec.machines[0].ports` to know what to forward. The list is plain strings, each either a port number (forward `localhost:N` → remote `127.0.0.1:N`) or `local:remote`:

```yaml
machines:
  - title: dev
    recipe: Ubuntu 24.04 LTS
    ports:
      - "5000"          # localhost:5000 → remote 127.0.0.1:5000
      - "8081:8080"     # localhost:8081 → remote 127.0.0.1:8080
```

This field is consumed by the CLI only — the backend ignores it.

## Discovering recipe and stack names

```sh
easyenv recipe list                   # OS / pre-baked machine images
easyenv recipe list --search python   # filter
easyenv stack list                    # catalog stack recipes
easyenv stack get docker-compose      # show the vars schema
```

Common recipes you'll see in the examples in this repo:

| Title                | Use for                                                    |
|----------------------|------------------------------------------------------------|
| `Ubuntu 24.04 LTS`   | Anything generic. Default for most labs.                   |
| `Python Dev Env`     | Pre-baked Python with pip, venv, vscode-server.            |
| `Kubernetes Cluster` | k3s pre-baked, ready for `kubectl` straight out of the box.|
| `PostgreSQL`         | PostgreSQL pre-installed.                                  |

Common stack recipes:

| Name             | Use for                                                |
|------------------|--------------------------------------------------------|
| `docker-run`     | Pull and run a Docker image (vars: `image`, `images`). |
| `docker-compose` | Bring up services from a compose script (var: `script`).|
| `bash`           | Append a snippet to `~/.bashrc` (var: `script`).       |
| `argocd`         | Install ArgoCD on a Kubernetes recipe.                 |
| `helm`, `k9s`, `kustomize`, `cert-manager`, `traefik`, `claude`, `vscode` | … browse with `easyenv stack list`. |

## Three complete examples

### Minimal — one Ubuntu box

```yaml
apiVersion: easyenv.io/v1
kind: Workspace
metadata:
  title: Simple Dev Box
spec:
  duration: 2
  duration_unit: hours
  machines:
    - title: dev
      recipe: Ubuntu 24.04 LTS
      resources:
        cpu: 2
        ram_mb: 2048
        storage_gb: 20
```

### Two boxes with networking

```yaml
apiVersion: easyenv.io/v1
kind: Workspace
metadata:
  title: Backend dev environment
spec:
  duration: 4
  duration_unit: hours
  cross_connection: true
  machines:
    - title: app
      recipe: Ubuntu 24.04 LTS
      resources:
        cpu: 4
        ram_mb: 4096
        storage_gb: 40
    - title: db
      recipe: PostgreSQL
      resources:
        cpu: 2
        ram_mb: 2048
        storage_gb: 20
```

`cross_connection: true` puts both boxes on the same NetBird mesh; from `app` you can `ssh easyenv@db` or `psql -h db -U postgres`.

### One box with a catalog stack and an inline stack

```yaml
apiVersion: easyenv.io/v1
kind: Workspace
metadata:
  title: Hello Flask
spec:
  duration: 4
  duration_unit: hours
  machines:
    - title: app
      recipe: Python Dev Env
      ports: ["5000"]
      stacks:
        - recipe: bash
          vars:
            script: |
              echo 'export FLASK_ENV=development' >> ~/.bashrc
        - title: install-flask
          runner: bash
          script: |
            pip install --break-system-packages flask
```

## Validating before you push

```sh
easyenv ws create -f .easyenv/workspace.yml --dry-run
```

Resolves recipe/stack names, applies validation, prints the request body — without sending anything. Drop it into CI to catch typos before they reach the server.
