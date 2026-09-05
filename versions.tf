terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.112.0" # pins to the 0.112.x patch line; bump deliberately
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11.0" # pins to the 0.11.x patch line; bump deliberately
    }
  }
}
