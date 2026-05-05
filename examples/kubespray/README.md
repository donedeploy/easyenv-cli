# kubespray — 3-node Kubernetes cluster via Kubespray

Three Ubuntu boxes on the same NetBird mesh. The first one (`master`) installs Kubespray at boot. Once all three are up, you run `make deploy` *on the master* via `easyenv here run`, and Kubespray brings up the cluster (Calico, CoreDNS, containerd, kubeadm — the works).

## What you'll learn

- Multi-box workspaces with `cross_connection: true`
- Why install-time stacks must not assume sibling boxes are reachable
- Driving a remote `make` target via `easyenv here run`

## Boxes don't come up in lockstep

This is the most important thing to understand before you run anything. Inline stacks attached to one machine run while that machine boots — siblings may still be provisioning. Anything that talks to a peer (Kubespray's `cluster.yml` SSH'ing into workers) **must wait for siblings first**.

The split this lab uses:

1. **`install-kubespray` stack** runs at boot on `master` only. It does *local* work — `apt install`, `git clone`, `pip install`. No peer access.
2. **`make deploy`** runs after `easyenv here up --wait 12m` returns (i.e. after all three boxes are confirmed active). It starts with a peer-wait helper that pings worker-1 and worker-2 over SSH, then hands off to Kubespray.

The peer-wait inside `make deploy` is belt-and-suspenders — even if `here up --wait` reports active, individual boxes may have a minute of cloud-init left.

## Quickstart

```sh
cd examples/kubespray

easyenv here up --wait 15m         # ~3-5 min for boxes to boot
easyenv here sync                  # push inventory + Makefile
easyenv here run --cmd 'make deploy'   # ~6-10 min for kubespray
```

When `make deploy` finishes, hop into the master and check the cluster:

```sh
easyenv here ssh
sudo kubectl get nodes
```

You should see three nodes, all `Ready`:

```
NAME       STATUS   ROLES           AGE   VERSION
master     Ready    control-plane   3m    v1.31.x
worker-1   Ready    <none>          2m    v1.31.x
worker-2   Ready    <none>          2m    v1.31.x
```

Tear down:

```sh
easyenv here down --force
```

## How it works

### `workspace.yml`

Three Ubuntu boxes, `cross_connection: true` so they can SSH to each other by `<box-title>` hostname:

```yaml
spec:
  cross_connection: true
  machines:
    - title: master
      stacks:
        - title: install-kubespray
          runner: bash
          script: |
            apt-get install -y python3-venv git rsync sshpass make
            git clone --depth 1 -b release-2.29 \
              https://github.com/kubernetes-sigs/kubespray.git /opt/kubespray
            ...

    - title: worker-1
    - title: worker-2
```

Workers have no stacks — they're plain Ubuntu, ready for Kubespray to configure them remotely.

### `inventory/easyenv/hosts.yaml`

A static Kubespray inventory keyed off the box titles. The `cross_connection` mesh provides DNS resolution for `master`, `worker-1`, `worker-2`, so no IP discovery step is needed.

### `Makefile`

Three targets, all run on the master via `easyenv here run --cmd 'make <target>'`:

- `wait` — poll `worker-1` and `worker-2` over SSH until they accept connections. Idempotent.
- `deploy` — runs `wait`, then `ansible-playbook cluster.yml`. Re-runnable.
- `reset` — runs Kubespray's `reset.yml` to wipe the cluster (in case something goes wrong and you want to retry).

The `status` target runs locally on master via `easyenv here ssh -- 'cd ~/project/examples/kubespray && make status'` if you want a quick `kubectl get nodes`.

## Troubleshooting

**`ssh: connect to host worker-X: Connection refused`** during `make wait`
The wait loop will retry forever, so just leave it — workers usually take ~2 minutes to boot. If it's been more than 5 minutes, run `easyenv ws watch` from another terminal and check whether the workers are stuck in `pending`.

**Kubespray fails on a specific role with a transient error**
Re-run `easyenv here run --cmd 'make deploy'` — Kubespray plays are idempotent and pick up where they left off.

**You want a fresh cluster**
`easyenv here run --cmd 'make reset'` to wipe, then `make deploy` again. Faster than `here down` + `here up`.

## Try this next

- [`postgres-cluster`](../postgres-cluster/) — same multi-box pattern, but with inline ansible instead of Kubespray.
- [`argocd`](../argocd/) — skip Kubespray entirely; use the pre-baked Kubernetes recipe.
