resource "proxmox_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore
  node_name    = var.proxmox_node

  # Naming it .img (not .iso) is what tells Proxmox to treat this as a raw
  # disk image that can be imported into a VM disk, rather than mounted as
  # a CD-ROM.
  file_name = "talos-v${var.talos_version}-nocloud-amd64.img"
  url       = "https://factory.talos.dev/image/${var.talos_schematic_id}/v${var.talos_version}/nocloud-amd64.raw.xz"

  # Image Factory has changed compression formats before (gz -> xz), and
  # what the provider needs here doesn't always match the URL's extension.
  # If this download fails, check factory.talos.dev for the currently
  # offered file and try "gz" or "xz" instead.
  decompression_algorithm = "zst"

  overwrite = false
}

moved {
  from = proxmox_virtual_environment_download_file.talos_image
  to   = proxmox_download_file.talos_image
}
