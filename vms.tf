resource "proxmox_virtual_environment_vm" "talos" {
  for_each = { for node in var.nodes : node.hostname => node }

  name      = each.value.hostname
  node_name = var.proxmox_node
  tags      = ["terraform", "talos", each.value.role]

  on_boot = true

  startup {
    order    = each.value.role == "controlplane" ? 1 : 2
    up_delay = each.value.role == "controlplane" ? 30 : 0
  }

  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
    floating  = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_vm_datastore
    file_id      = proxmox_download_file.talos_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_gb
  }

  # Using the raw disk image (instead of booting the ISO installer) boots
  # straight into Talos and lets us set a static IP via Proxmox's own
  # cloud-init support.
  initialization {
    datastore_id = var.proxmox_vm_datastore

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_cidr_suffix}"
        gateway = var.network_gateway
      }
    }
  }

  network_device {
    bridge = var.network_bridge
  }

  operating_system {
    type = "l26"
  }
}
