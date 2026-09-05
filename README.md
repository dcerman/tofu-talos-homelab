# Talos Kubernetes homelab — OpenTofu module

Provisions a 1 control-plane / 2 worker Talos Linux cluster as VMs on a single
Proxmox host, using:

- [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest) — downloads the Talos image and creates the VMs
- [`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos/latest) — generates machine configs, applies them, and bootstraps the cluster

## Prerequisites

1. **The internal bridge (`vmbr0`, `10.10.10.0/24`, NAT) exists on the Proxmox host.**
   This module attaches VMs to it but doesn't create it.
2. **A Proxmox API token and a service-account SSH key exist** — see below.
3. `opentofu` and `talosctl` installed locally (already done).

## Setting up Proxmox access

Run these on the Proxmox host itself (console or `ssh root@<proxmox-ip>`):

```sh
# 1. A role scoped to what OpenTofu actually needs
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit \
  VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk \
  VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate \
  VM.Monitor VM.PowerMgmt SDN.Use"

# 2. A dedicated PVE-realm service account (not a real login) with that role
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role TerraformProv

# 3. An API token for it — privsep 0 means the token inherits the user's
#    role directly, which is simplest for a single-purpose homelab token
pveum user token add terraform@pve opentofu --privsep 0
# ^ prints the token secret ONCE — copy it into terraform.tfvars immediately
```

The `bpg/proxmox` provider also falls back to SSH for a few operations —
notably importing the downloaded Talos image into a VM disk — even when
using an API token for everything else. Set that up too:

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
