# Stacks: catalog vs inline

A *stack* is a piece of configuration applied on top of a recipe. Recipes give you the OS and the pre-baked tooling; stacks layer on the bits unique to your project — Docker images to pull, services to start, packages to install, secrets to drop in.

There are two kinds: **catalog** stacks (curated, named entries from `easyenv stack list`) and **inline** stacks (ad-hoc bash or Ansible written directly in `workspace.yml`).

## Catalog stacks

Catalog stacks are versioned, take typed `vars`, and ship with vetted defaults. You reference them by name.

```yaml
stacks:
  - recipe: docker-run
    vars:
      image: nginx:latest
```

Pros:

- Curated and documented — `easyenv stack get <name>` shows the vars schema.
- The web UI gives you a form, so you can wire the same stack from CLI or browser.
- Sensitive vars (registry credentials, API keys) get encrypted at rest and masked in the UI.

Use a catalog stack when one exists for what you're doing — pulling Docker images, running compose, installing ArgoCD, dropping in a vscode-server, etc.

### Some popular ones

| Name             | Purpose                                                                                | Key vars                  |
|------------------|----------------------------------------------------------------------------------------|---------------------------|
| `docker-run`     | Pull and (optionally) run a Docker image. Cache extra images for offline use.          | `image`, `images`, `credentials` |
| `docker-compose` | Drop a compose script and bring it up.                                                 | `script`                  |
| `bash`           | Install bash + oh-my-bash and append a snippet to `~/.bashrc`.                         | `script`                  |
| `argocd`         | Install ArgoCD into a k8s recipe.                                                      |                           |
| `helm`           | Install Helm.                                                                          |                           |
| `k9s`            | Install k9s.                                                                           |                           |
| `kustomize`      | Install Kustomize.                                                                     |                           |
| `cert-manager`   | Install cert-manager into a k8s recipe.                                                |                           |
| `prometheus-grafana` | Install Prometheus + Grafana into a k8s recipe.                                    |                           |
| `traefik`        | Install Traefik.                                                                       |                           |
| `claude`         | Install Claude Code.                                                                   | `ANTHROPIC_API_KEY`       |
| `vscode`         | Install vscode-server.                                                                 |                           |

Browse the rest:

```sh
easyenv stack list
easyenv stack get docker-compose
```

## Inline stacks

Inline stacks are written right in `workspace.yml`. Two runners: `bash` and `ansible`.

```yaml
stacks:
  - title: install-flask
    runner: bash
    script: |
      pip install --break-system-packages flask
```

```yaml
stacks:
  - title: configure-postgres
    runner: ansible
    playbook: |
      - hosts: localhost
        become: yes
        tasks:
          - apt: { name: postgresql-16, state: present }
          - lineinfile:
              path: /etc/postgresql/16/main/postgresql.conf
              regexp: '^#?wal_level'
              line: 'wal_level = replica'
          - service: { name: postgresql, state: restarted }
```

Pros:

- Versioned in your repo alongside the workspace spec.
- No round-trip through the catalog — change the script, `easyenv here up`, done.
- Right escape hatch for project-specific bootstrapping.

Use inline when a catalog stack doesn't exist or doesn't fit — bespoke install steps, project-specific configuration, one-off scripts.

## Quick-pick guide

| Situation                                                         | Use                                  |
|-------------------------------------------------------------------|--------------------------------------|
| You want to run a Docker image                                    | `docker-run` (catalog)               |
| You want to bring up a compose file                               | `docker-compose` (catalog)           |
| You want to install ArgoCD/Helm/k9s/Traefik/etc. on Kubernetes    | the matching catalog stack           |
| You're installing a Python/Node/Go package on a generic Ubuntu box| inline `runner: bash`                |
| You're configuring a service that needs idempotent edits          | inline `runner: ansible`             |
| You need cross-node setup (e.g. Postgres replication)             | inline ansible **after** boxes are up — see [`postgres-cluster/`](../examples/postgres-cluster/) |

## Important: boxes don't come up in lockstep

Inline stacks attached to *one* machine run as that machine boots — siblings may still be provisioning. Anything that reaches out to a peer (kubespray's `cluster.yml`, Postgres's `pg_basebackup`) must wait for siblings first.

The clean pattern is to split work in two:

1. **Boot-time inline stack** — only does *local* installs (apt, pip, git clone). Safe to race siblings.
2. **Post-up step** — driven by `easyenv here run --cmd 'make deploy'` after `easyenv here up --wait 10m` returns. By that point all peers are reachable.

The [`kubespray/`](../examples/kubespray/) and [`postgres-cluster/`](../examples/postgres-cluster/) examples show this in practice — install at boot, configure cross-node bits via `make` later.

If you really do want to wait inside an inline stack, the helper looks like this:

```bash
wait_for_peer() {
  local host=$1
  until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
            -o BatchMode=yes easyenv@"$host" true 2>/dev/null; do
    echo "[wait] $host …"
    sleep 5
  done
}
for h in worker-1 worker-2; do wait_for_peer "$h"; done
```

(The SSH user inside cross-connected workspaces is always `easyenv`; sibling hostnames are the box `title:` values from `workspace.yml`.)
