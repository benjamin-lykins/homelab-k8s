# Homelab docs

Documentation of the current homelab Kubernetes setup and the workloads the
Terraform components in this repo deploy onto it.

- [cluster.md](cluster.md) — node inventory, network config, k3s bootstrap details
- [kube-vip.md](kube-vip.md) — control-plane VIP setup and a gotcha to avoid
- [longhorn.md](longhorn.md) — Longhorn replicated block storage (`longhorn` StorageClass)
- [n8n.md](n8n.md) — n8n workflow automation at http://n8n.192.168.39.20.nip.io/ (nip.io address, encryption key, upgrades)
- [nfs.md](nfs.md) — `nfs` StorageClass (csi-driver-nfs) backed by the rasppi NAS, plus the Longhorn backup target
- [rasppi.md](rasppi.md) — Raspberry Pi 4 NAS running OpenMediaVault at 192.168.39.30 (wired) / .31 (WiFi), not part of the cluster
- [manifests/](manifests/) — reference copies of manifests applied directly via
  `kubectl` (not stored as auto-deploying k3s manifests on any node — see
  cluster.md for why)
