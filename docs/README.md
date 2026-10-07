# Homelab docs

Documentation of the current homelab Kubernetes setup, as distinct from the
`grafana/` Terraform (which deploys monitoring *onto* this cluster).

- [cluster.md](cluster.md) — node inventory, network config, k3s bootstrap details
- [kube-vip.md](kube-vip.md) — control-plane VIP setup and a gotcha to avoid
- [manifests/](manifests/) — reference copies of manifests applied directly via
  `kubectl` (not stored as auto-deploying k3s manifests on any node — see
  cluster.md for why)
