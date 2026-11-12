# kubespray — 3-node Kubernetes cluster via Kubespray

Three Ubuntu boxes in one workspace. The master's inline-ansible install stack does everything that needs the EasyEnv API (sibling IPs, kubespray inventory) at boot, while the box token is fresh. `make deploy` then just runs Kubespray's `cluster.yml`.

## easyenv features used

- **Sibling names**: the three boxes reach each other by title (`/etc/hosts`, kept current at boot and on a timer). `cross_connection: true` is still in the file but no longer needed.
- **Multi-machine workspace** — one machine carries the install stack; the other two are plain Ubuntu, configured remotely by Kubespray.
- **Inline-ansible stack** (`runner: ansible` + `playbook:`) for boot-time install. Lets us use `uri`, `copy`, `template`, retries.
- **EasyEnv per-box API** via `/etc/box_configs.json` (provisioned on every box) and `GET /v1/vm/box` — called from inside the install stack to discover sibling IPs.
- **`easyenv here run --cmd '<cmd>'`** — drives a remote `make` target from your laptop.

## Why discovery happens at boot, not deploy

The `api_token` in `/etc/box_configs.json` is a JWT with a **60-minute lifetime and no refresh**. If we called the API at deploy time, anyone running `make deploy` more than an hour after `make up` would hit a 401.

So the install stack does the API call **once**, while the token is still fresh, and writes the kubespray inventory to `/home/easyenv/kubespray-inventory.yaml`. After that we never touch the API again. Inventory persists; `make deploy` just runs `cluster.yml`.

## Boxes don't come up in lockstep

Inline stacks attached to one machine run while that machine boots — siblings may still be provisioning. The install stack handles this by retrying `GET /v1/vm/box` until **every** sibling has a non-empty `ip_address` (30 attempts × 10s = 5 min ceiling). Only then does it render the inventory. Kubespray itself runs later via `make deploy`, so by then everyone is fully booted.

## Quick start

```sh
cd examples/kubespray

make up          # easyenv here up --wait 15m   (~3-5 min; install stack does the API call here)
make deploy      # easyenv here sync + ansible-playbook cluster.yml on the master  (~6-10 min)
make status      # kubectl get nodes (on the master)

# Drive kubectl from your laptop:
make kube                       # writes ./kubeconfig (server rewritten to 127.0.0.1:6443)
make expose                     # in a separate terminal — wait for 'forwarding ...'
make kctl ARGS='get nodes'      # convenience wrapper (KUBECONFIG already set)
# or:
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
```

Tear down:

```sh
make down
```

## Make targets

Each local target echoes its underlying `easyenv` command before running. Remote targets (prefixed `remote-`) run on the master and are normally invoked by a local target via `easyenv here run`.

| Target | Underlying commands | What it does |
|--------|---------------------|--------------|
| `make up`     | `easyenv here up --wait 15m`    | Create + start all three boxes. The master's install-kubespray inline-ansible stack runs at boot: installs deps, clones kubespray, calls the EasyEnv API for sibling IPs, renders `~/kubespray-inventory.yaml`. |
| `make sync`   | `easyenv here sync`             | rsync the project root (`Makefile`) to `~/project` on the master. |
| `make deploy` | `easyenv here sync` <br> `easyenv here run --cmd 'make remote-deploy'` | Push files, then on the master: run kubespray's `cluster.yml` against the boot-rendered inventory. |
| `make reset`  | `easyenv here sync` <br> `easyenv here run --cmd 'make remote-reset'`  | Push files, then on the master: run kubespray's `reset.yml` (wipes the cluster). |
| `make status` | `easyenv here run --cmd 'make remote-status'` | On the master: `kubectl get nodes -o wide`. |
| `make kube`   | `easyenv here run --cmd 'make remote-kubeconfig'` (filtered) | Fetch `/etc/kubernetes/admin.conf` from the master, rewrite `server:` to `https://127.0.0.1:6443`, save to `./kubeconfig`. |
| `make kctl ARGS='...'` | `KUBECONFIG=./kubeconfig kubectl $(ARGS)` | One-shot kubectl with the local kubeconfig already set. Needs `make expose` running. |
| `make ssh`    | `easyenv here ssh`              | Open an interactive shell on the master. |
| `make expose` | `easyenv here expose`           | Forward `ports[]` from `workspace.yml` to localhost (6443 included). |
| `make down`   | `easyenv here down --force`     | Stop and delete the workspace. |
| `make remote-deploy` | `cd /opt/kubespray && ansible-playbook -i ~/kubespray-inventory.yaml cluster.yml -b -u easyenv` | (Remote) full kubespray deploy. |
| `make remote-reset`  | `cd /opt/kubespray && ansible-playbook -i ~/kubespray-inventory.yaml reset.yml -b -u easyenv -e reset_confirmation=yes` | (Remote) wipe the cluster. |
| `make remote-status` | `sudo kubectl get nodes -o wide` | (Remote) cluster node state. |
| `make remote-kubeconfig` | `sudo cat /etc/kubernetes/admin.conf` (between markers) | (Remote) print kubeconfig wrapped in `===KUBECONFIG-BEGIN/END===` so the laptop side can grep it out cleanly past `easyenv here run`'s rsync header. |

## How it works

### `workspace.yml`

Three Ubuntu boxes, `cross_connection: true`. The master carries one inline-ansible stack:

```yaml
spec:
  cross_connection: true
  machines:
    - title: master
      stacks:
        - title: install-kubespray
          runner: ansible
          playbook: |
            - hosts: localhost
              become: yes
              tasks:
                - apt: { name: [python3-venv, git, rsync, sshpass, make], state: present }
                - git: { repo: https://github.com/kubernetes-sigs/kubespray.git, dest: /opt/kubespray, version: release-2.29, depth: 1 }
                - pip: { requirements: /opt/kubespray/requirements.txt, virtualenv: /opt/kubespray/.venv, virtualenv_command: python3 -m venv }
                # ... API call for sibling IPs, render inventory ...

    - title: worker-1
    - title: worker-2
```

Workers have no stacks — plain Ubuntu, configured remotely by Kubespray.

### Inventory render at boot

Inside the install stack:

1. **Read** `/etc/box_configs.json` to get the API base URL and bearer token.
2. **`GET /v1/vm/box`** with retries: keep retrying until every sibling has a non-empty `ip_address`. 30 × 10s = 5-minute ceiling.
3. **Render** `~/kubespray-inventory.yaml` via `copy: content:` with inline Jinja. Each host's `ansible_host` is the sibling's real IP, host keys are lowercased (kubespray's preinstall regex requires lowercase), and the running box becomes the control plane (`kube_control_plane` and `etcd` groups).

### `Makefile`

- **Local** targets wrap `easyenv here ...`.
- **Remote** targets run on the master via `easyenv here run`. They use Kubespray's bundled venv (`/opt/kubespray/.venv/bin/ansible-playbook`) and `cd /opt/kubespray` so kubespray's `ansible.cfg` (which sets `roles_path = roles:playbooks/roles`) gets loaded.

## Troubleshooting

**Install stack times out with `Fetch self + siblings from EasyEnv API`**
The retry budget is 5 min. If a sibling is genuinely stuck pending, look at `easyenv ws watch` from another terminal. Once the sibling has an IP, `easyenv here up` again to re-trigger the install stack.

**Kubespray fails on a specific role with a transient error**
Re-run `make deploy` — Kubespray plays are idempotent and pick up where they left off.

**You want a fresh cluster**
`make reset` to wipe via Kubespray's `reset.yml`, then `make deploy` again. Faster than `make down` + `make up`.

**You added/removed a worker**
The inventory was rendered at boot from the snapshot of siblings at that moment. If the workspace changes, run `make down && make up` to regenerate.

## Connecting kubectl from your laptop

`make kube` pipes `sudo cat /etc/kubernetes/admin.conf` from the master and writes it to `./kubeconfig`. Two adjustments along the way:

- **awk filter** strips the `easyenv here run` rsync header (`sending incremental file list`, `sent X bytes ...`, `total size is …`). The remote target wraps the actual file content in `===KUBECONFIG-BEGIN===`/`===KUBECONFIG-END===` markers so we can extract it reliably regardless of what else lands on stdout.
- **sed rewrite** changes `server: https://<master-ip>:6443` to `server: https://127.0.0.1:6443`. Kubespray includes `127.0.0.1` in the apiserver cert SANs by default, so TLS verification still works once you tunnel.

To use it:

```sh
make kube                          # one-time
make expose &                      # holds 6443 open
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
```

`./kubeconfig` is `.gitignore`d (it contains a client cert). Re-run `make kube` after `make reset && make deploy` if certs rotate.

## Try this next

- [`postgres-cluster`](../postgres-cluster/) — same multi-box pattern, but with inline ansible instead of Kubespray.
- [`argocd`](../argocd/) — skip Kubespray entirely; use the pre-baked Kubernetes recipe.
