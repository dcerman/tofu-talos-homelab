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

# Authenticates against the cluster this module just created, using the
# kubeconfig from talos_cluster_kubeconfig.this (talos.tf). This makes the
# helm provider's config depend on a resource — expected for a bootstrap
# module like this one. It means `tofu plan` against a not-yet-created
# cluster shows this provider's values as "(known after apply)", which is
# normal here, not an error.
provider "helm" {
  kubernetes = {
    host                   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.server
    cluster_ca_certificate = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user["client-certificate-data"])
    client_key             = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user["client-key-data"])
  }
}
