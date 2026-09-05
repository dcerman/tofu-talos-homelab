provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # A handful of bpg/proxmox operations (notably importing the downloaded
  # Talos disk image into a VM) fall back to SSH even when using an API
  # token for the REST calls. See the README for how to set this key up.
  ssh {
    username    = var.proxmox_ssh_username
    private_key = file(var.proxmox_ssh_private_key_path)
  }
}

provider "talos" {}
