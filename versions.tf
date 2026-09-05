terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.97.0, < 1.0.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.0, < 0.13.0"
    }
  }
}
