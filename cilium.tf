# Installs Cilium as the cluster's CNI, replacing the Flannel default that's
# disabled via the cluster.network.cni.name = "none" patch in talos.tf.
#
# Runs kube-proxy alongside Cilium (not the kube-proxy-free "strict" mode) —
# the simpler, lower-risk starting point. Talos will retry/reboot the nodes
# if no CNI shows up within ~10 minutes of bootstrap; on a homelab, this
# helm_release should complete well inside that window once the kubeconfig
# is available.
#
# Values match the Talos-specific overrides Sidero's docs recommend:
# https://docs.siderolabs.com/kubernetes-guides/cni/deploying-cilium
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.20.1" # check https://github.com/cilium/cilium/releases for a newer patch before applying

  namespace = "kube-system"

  depends_on = [talos_cluster_kubeconfig.this, data.talos_cluster_health.this]

  values = [
    yamlencode({
      ipam = {
        mode = "kubernetes"
      }

      # Coexists with kube-proxy for now. Once Cilium is confirmed healthy,
      # a good follow-up is switching this to true (plus setting
      # k8sServiceHost/k8sServicePort and disabling kube-proxy in Talos'
      # machine config) for the full kube-proxy-free setup.
      kubeProxyReplacement = false

      # Talos doesn't allow Kubernetes workloads to load kernel modules, so
      # SYS_MODULE must be dropped from Cilium's default capability set.
      securityContext = {
        capabilities = {
          ciliumAgent = [
            "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK",
            "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER",
            "SETGID", "SETUID",
          ]
          cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
        }
      }

      # Talos already provides the cgroupv2 mount; don't let Cilium try to
      # mount its own.
      cgroup = {
        autoMount = { enabled = false }
        hostRoot  = "/sys/fs/cgroup"
      }
    }),
  ]
}
