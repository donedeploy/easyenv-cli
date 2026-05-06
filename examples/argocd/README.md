# argocd — ArgoCD on a 3-node Kubernetes cluster

Three boxes spun from the **Kubernetes Cluster** recipe (k3s already installed). The `argocd` catalog stack drops ArgoCD onto the first node. No Kubespray, no Ansible — the recipe and the stack do everything.

## easyenv features used

- **`Kubernetes Cluster` recipe** — k3s, kubectl, containerd pre-baked. Available via `easyenv recipe list`.
- **`argocd` catalog stack** composed on top of a recipe (compatibility declared in the stack's `default_compatibility.recipes`). Browse with `easyenv stack list` for siblings: `helm`, `k9s`, `cert-manager`, `prometheus-grafana`, `traefik`, `cilium`.
- **Multi-machine workspace** — three nodes; only the first carries the stack, the others auto-join the cluster via the recipe.

## Quick start

```sh
cd examples/argocd

make up
make ssh
```

You're on `k8s-1`. The cluster and ArgoCD are already running:

```sh
sudo kubectl get nodes
sudo kubectl get pods -n argocd
```

You should see all three nodes `Ready` and the ArgoCD pods `Running`.

To open the ArgoCD UI in your browser, port-forward from inside the box and forward to your laptop:

```sh
# inside the box
sudo kubectl port-forward -n argocd svc/argocd-server 8080:443 --address 0.0.0.0 &
exit
```

Then on your laptop:

```sh
# add ports: ["8080"] to .easyenv/workspace.yml first, or use machine port-forward:
easyenv machine port-forward k8s-1 -w <ws-uuid> 8080:8080
```

(Or just stay inside the box and use the CLI: `argocd login`, `argocd app create`, etc.)

The default admin password is stored in the secret `argocd-initial-admin-secret`:

```sh
sudo kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Tear down:

```sh
make down
```

## Make targets

Each target echoes its underlying `easyenv` command before running.

| Target | Runs | What it does |
|--------|------|--------------|
| `make up`     | `easyenv here up --wait 10m` | Create + start the 3-box workspace. The `argocd` stack `kubectl apply`s ArgoCD onto k8s-1 during boot. |
| `make deploy` | (alias for `make up`)        | The catalog stack does everything during `up`; deploy is just an alias. |
| `make ssh`    | `easyenv here ssh`           | Open an interactive shell on `k8s-1`. |
| `make expose` | `easyenv here expose`        | No `ports[]` is set in this example by default — add one to `workspace.yml` first. |
| `make down`   | `easyenv here down --force`  | Stop and delete the workspace. |

## How it works

```yaml
machines:
  - title: k8s-1
    recipe: Kubernetes Cluster      # k3s, kubectl, containerd — pre-baked
    stacks:
      - recipe: argocd              # catalog stack — installs ArgoCD via official manifest
```

That's it. The `argocd` stack lists `k8s_cluster` in its `default_compatibility.recipes`, so the CLI knows it can be applied here. The stack runs an Ansible playbook on the box that `kubectl apply`s the official ArgoCD install manifest into the local k3s cluster.

`k8s-2` and `k8s-3` are along for the ride — they make the cluster a real 3-node setup so you can actually test scheduling, but ArgoCD itself only needs the first node.

No `cross_connection`-driven peer-wait is needed: the argocd stack installs into the *local* cluster on `k8s-1`. The other nodes join the cluster on their own (handled by the recipe).

## Why this is so much shorter than `kubespray`

Two reasons:

1. The **Kubernetes Cluster** recipe ships k3s already installed and configured — you skip the entire "provision Kubernetes" step.
2. The **argocd** catalog stack handles ArgoCD installation — you skip the "write a kubectl apply playbook" step.

If you need a specific Kubernetes flavor (`vanilla` kubeadm, a specific CNI, custom kubelet flags, etc.), the [`kubespray`](../kubespray/) lab shows the long way. For most things, this lab is fine.

## Try this next

- [`kubespray`](../kubespray/) — same shape, but you build the cluster from raw Ubuntu.
- Browse `easyenv stack list` for other things you can drop on top of the Kubernetes Cluster recipe — `helm`, `k9s`, `cert-manager`, `prometheus-grafana`, `traefik`, `cilium`, …
