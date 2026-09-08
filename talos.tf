locals {
  control_plane_nodes     = [for n in var.nodes : n if n.role == "controlplane"]
  worker_nodes            = [for n in var.nodes : n if n.role == "worker"]
  node_ips                = [for n in var.nodes : n.ip]
  primary_control_node_ip = local.control_plane_nodes[0].ip
  cluster_endpoint        = "https://${local.primary_control_node_ip}:6443"

  # Tells Talos to pull its install image (including the qemu-guest-agent
  # extension) from Image Factory on upgrades, instead of falling back to
  # the bare upstream image and losing the extension.
  install_image = "factory.talos.dev/installer/${var.talos_schematic_id}:v${var.talos_version}"
}

resource "talos_machine_secrets" "this" {
  talos_version = "v${var.talos_version}"
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in local.control_plane_nodes : n.ip]
  nodes                = local.node_ips
}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v${var.talos_version}"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda" # matches the virtio0 disk on the VM
          image = local.install_image
        }
      }
      # Disables the default Flannel CNI so Cilium (installed separately via
      # helm_release in cilium.tf) can take over instead. Must match on both
      # controlplane and worker configs.
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    }),
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = "v${var.talos_version}"

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk  = "/dev/vda"
          image = local.install_image
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for n in local.control_plane_nodes : n.hostname => n }

  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.ip
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = { for n in local.worker_nodes : n.hostname => n }

  depends_on                  = [proxmox_virtual_environment_vm.talos]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.primary_control_node_ip
  endpoint             = local.primary_control_node_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.primary_control_node_ip
}

# Bootstrap completing and the kubeconfig being generated both happen almost
# instantly — neither actually confirms the API server is up yet (etcd and
# the control plane static pods still need to start). Without this gate,
# helm_release.cilium tries to connect before anything is listening on
# :6443 and fails with "connection refused".
#
# skip_kubernetes_checks = true is required here: the full check also waits
# for all k8s nodes to report Ready, kube-proxy, and CoreDNS — all of which
# depend on a CNI already being installed, which is exactly what hasn't
# happened yet at this point in the graph. This only waits for the
# pre-Kubernetes layer (etcd, apid, boot sequence).
data "talos_cluster_health" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration   = talos_machine_secrets.this.client_configuration
  control_plane_nodes    = [for n in local.control_plane_nodes : n.ip]
  worker_nodes           = [for n in local.worker_nodes : n.ip]
  endpoints              = [for n in local.control_plane_nodes : n.ip]
  skip_kubernetes_checks = true
}
