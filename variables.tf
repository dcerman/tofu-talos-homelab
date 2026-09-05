# ---------------------------------------------------------------------------
# Proxmox connection
# ---------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://192.168.1.20:8006"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token, form: user@realm!tokenid=uuid (see README for creating this)"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for the default self-signed Proxmox cert)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH username on the Proxmox host, used for the handful of operations bpg/proxmox can't do over the API alone (e.g. disk import)"
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to the private key that authenticates proxmox_ssh_username"
  type        = string
  default     = "~/.ssh/proxmox_opentofu"
}

variable "proxmox_node" {
  description = "Name of the Proxmox node to deploy on — check Datacenter in the Proxmox UI, it's often not just 'pve'"
  type        = string
}

variable "proxmox_iso_datastore" {
  description = "Datastore ID that will hold the downloaded Talos image (must allow ISO/image content)"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore" {
  description = "Datastore ID for VM disks — your ext4 + LVM-thin pool, commonly 'local-lvm'"
  type        = string
  default     = "local-lvm"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox bridge the Talos VMs attach to"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Gateway for the internal Talos network"
  type        = string
  default     = "10.10.10.1"
}

variable "network_cidr_suffix" {
  description = "CIDR suffix for the internal Talos network"
  type        = number
  default     = 24
}

# ---------------------------------------------------------------------------
# Talos / cluster
# ---------------------------------------------------------------------------

variable "talos_version" {
  description = "Talos Linux version to deploy (without the leading v)"
  type        = string
  default     = "1.13.6"
}

variable "talos_schematic_id" {
  description = "Image Factory schematic ID (nocloud + qemu-guest-agent extension)"
  type        = string
  default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "cluster_name" {
  description = "Name for the Talos/Kubernetes cluster"
  type        = string
  default     = "homelab"
}

variable "nodes" {
  description = "Talos VM definitions. role must be \"controlplane\" or \"worker\". memory is in MB."
  type = list(object({
    hostname = string
    ip       = string
    role     = string
    cores    = number
    memory   = number
    disk_gb  = number
  }))

  # Lean sizing for a single 16GB-RAM host: ~3GB for the control plane,
  # 4GB per worker, leaving headroom for the Proxmox host itself.
  # Bump these once the RAM upgrade lands.
  default = [
    { hostname = "talos-cp1", ip = "10.10.10.11", role = "controlplane", cores = 2, memory = 3072, disk_gb = 20 },
    { hostname = "talos-wk1", ip = "10.10.10.12", role = "worker", cores = 2, memory = 4096, disk_gb = 40 },
    { hostname = "talos-wk2", ip = "10.10.10.13", role = "worker", cores = 2, memory = 4096, disk_gb = 40 },
  ]

  validation {
    condition     = alltrue([for n in var.nodes : contains(["controlplane", "worker"], n.role)])
    error_message = "Each node's role must be either \"controlplane\" or \"worker\"."
  }

  validation {
    condition     = length([for n in var.nodes : n if n.role == "controlplane"]) > 0
    error_message = "At least one node must have role = \"controlplane\"."
  }
}
