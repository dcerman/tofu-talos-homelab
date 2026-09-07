# Talos Kubernetes homelab — OpenTofu module

Provisions a 1 control-plane / 2 worker Talos Linux cluster as VMs on a single
Proxmox host, using:

- [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest) — downloads the Talos image and creates the VMs
- [`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos/latest) — generates machine configs, applies them, and bootstraps the cluster

## Prerequisites

1. **`tofu-proxmox-bootstrap` has been applied.** That project creates
   the Proxmox role/user/API token this module authenticates with, and
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
node, and generate a kubeconfig.

If you're running `tofu`/`talosctl`/`kubectl` from a machine other than
the Proxmox host itself, that machine also needs a route to
`10.10.10.0/24` — see `tofu-proxmox-bootstrap`'s README for why and how.

Grab your config files:

```sh
tofu output -raw talosconfig > talosconfig.yaml
tofu output -raw kubeconfig > kubeconfig.yaml

export TALOSCONFIG=$PWD/talosconfig.yaml
export KUBECONFIG=$PWD/kubeconfig.yaml

talosctl health
kubectl get nodes
```

## Notes / things you'll likely want to change next

- **No CNI decision baked in.** Talos ships Flannel by default, which is
  fine to start with. Swapping to Cilium (recommended if you want Gateway
  API / L2 announcements later) is a config-patch change, not a rewrite.
- **No control-plane HA / VIP.** One control-plane node is the right call
  on a single 16GB stick. Once the RAM upgrade lands, bump `var.nodes` to
  3 control-plane nodes and add a `vip` patch — it's an incremental change.
- **`decompression_algorithm` in `image.tf`** is set to `"zst"` even though
  the URL ends in `.raw.xz` — that's what currently works against Image
  Factory, but it's worth a second look if the download step fails.
- **`talos_client_configuration`'s `endpoints`** should list control-plane
  nodes only — worker nodes belong in `nodes`, not `endpoints`. Listing
  all three as endpoints causes `talosctl` errors.
