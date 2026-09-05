output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "control_plane_ip" {
  value = local.primary_control_node_ip
}

output "worker_ips" {
  value = [for n in local.worker_nodes : n.ip]
}
