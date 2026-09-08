# Talos Kubernetes homelab — OpenTofu module

Provisions a 1 control-plane / 2 worker Talos Linux cluster as VMs on a single
Proxmox host, using:

- [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest) — downloads the Talos image and creates the VMs
- [`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos/latest) — generates machine configs, applies them, and bootstraps the cluster
- [`hashicorp/helm`](https://registry.terraform.io/providers/hashicorp/helm/latest) — installs Cilium (the cluster's CNI) once the cluster is reachable

## Architecture

The Proxmox bootstrap project creates the isolated network used by this
cluster. This project creates the Talos VMs and Kubernetes cluster on that
network.

```text
LAN: 192.168.1.0/24
        |
        | 192.168.1.20
        |
   Proxmox host
        |
        | talosnet: 10.10.10.0/24
        | gateway: 10.10.10.1
        |
        +-- 10.10.10.10  (VIP, floats across control-plane nodes)
        +-- 10.10.10.11  talos-cp1  (control plane)
        +-- 10.10.10.12  talos-wk1  (worker)
        +-- 10.10.10.13  talos-wk2  (worker)
```

The administrative workstation is outside the isolated Talos network. To
reach the nodes from the workstation, it needs a route to `10.10.10.0/24`
via the Proxmox host's LAN address. See `tofu-proxmox-bootstrap`'s README
for the workstation-specific configuration.

## Prerequisites

1. **`tofu-proxmox-bootstrap` has been applied.** That project creates the
   Proxmox role/user/API token this module authenticates with, and
   the isolated internal network (`talosnet`, `10.10.10.0/24`, NAT) these
   VMs attach to — this module creates neither.
2. **A service-account SSH key exists** — see below.
3. `opentofu` and `talosctl` installed locally (already done).

## Setting up Proxmox access

Run `tofu-proxmox-bootstrap` first — it creates the scoped role, service
account, and API token this module needs, plus the internal network
these VMs attach to (see that repo's README). Paste its
`opentofu_api_token` output into this project's `terraform.tfvars` as
`proxmox_api_token`, and its `network_vnet_id` output as `network_bridge`
(this already matches the variable's default, so only needed if you
customized it there).

The `bpg/proxmox` provider also falls back to SSH for a few operations —
notably importing the downloaded Talos image into a VM disk — even when
using an API token for everything else. That's still a manual, one-time
step here:

```sh
# On your laptop
ssh-keygen -t ed25519 -f ~/.ssh/proxmox_opentofu -N ""
ssh-copy-id -i ~/.ssh/proxmox_opentofu.pub root@<proxmox-ip>
```

## Usage

```sh
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your endpoint, token, and node name

tofu init
tofu plan
tofu apply
```

This will, in order: download the Talos image, create the three VMs, apply
machine configuration to each, bootstrap the cluster on the control-plane
node, wait for etcd/apid to report healthy, generate a kubeconfig, and
install Cilium as the cluster's CNI. The Cilium install is usually the
longest single step (under a minute on this hardware).

If you're running `tofu`/`talosctl`/`kubectl` from a machine other than
the Proxmox host itself, that machine also needs a route to
`10.10.10.0/24` — see `tofu-proxmox-bootstrap`'s README for why and how.

Grab your config files:

```sh
tofu output -raw talosconfig > talosconfig.yaml
tofu output -raw kubeconfig > kubeconfig.yaml

export TALOSCONFIG=$PWD/talosconfig.yaml
export KUBECONFIG=$PWD/kubeconfig.yaml

talosctl health -n 10.10.10.11
kubectl get nodes -o wide
kubectl get pods -n kube-system -l k8s-app=cilium
```

## Notes / things you'll likely want to change next

- **CNI: Cilium**, installed via `helm_release` in `cilium.tf`, replacing
  Talos's default Flannel (disabled via the `cluster.network.cni.name =
  none` patch in `talos.tf`). Runs alongside kube-proxy for now, not the
  kube-proxy-free mode — switching to that later is a values change, not
  a rewrite. Talos only evaluates the CNI setting at initial bootstrap, so
  changing CNIs again means a full `tofu destroy` / `tofu apply`, not an
  in-place update.
- **Control-plane VIP: wired in, not yet battle-tested.** `var.network_vip`
  (default `10.10.10.10`) is configured on every control-plane node via a
  `vip` patch, and `cluster_endpoint` points at it rather than a specific
  node — this is what would survive `talos-cp1` going down. With only one
  control-plane node running today, this has only been confirmed to make
  the VIP reachable, not that failover actually works — that needs a
  second control-plane node to verify for real. The patch assumes the
  VM's interface is named `eth0`; confirm with `talosctl get links -n
  <node-ip>` before applying if the VM's NIC setup ever changes.
- **Adding more control-plane nodes** is just adding entries to
  `var.nodes` with `role = "controlplane"` — VM creation, machine config,
  and the health check already use `for_each`/list comprehensions over
  every control-plane node, not just the first. RAM is the real
  constraint on a single 16GB stick, not the code.
