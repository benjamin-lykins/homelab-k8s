# Cluster overview

A 3-node k3s cluster with embedded etcd (every node is a server / control-plane /
etcd member — no dedicated agent nodes). Rebuilt from scratch 2026-09-18 to move
off WiFi/DHCP onto static wired IPs, after DHCP lease churn broke etcd raft
peering (see "History" below).

## Nodes

| Hostname | Static IP | Interface | MAC | OS |
|---|---|---|---|---|
| mf-095 | 192.168.39.10 | enp1s0 | 58:47:ca:76:32:25 | Debian 13 (trixie) |
| mf-113 | 192.168.39.11 | enp1s0 | 58:47:ca:76:39:a9 | Debian 13 (trixie) |
| mf-167 | 192.168.39.12 | enp1s0 | 58:47:ca:76:3c:ab | Debian 13 (trixie) |

Each node also has a second onboard NIC (`enp3s0`) that is unused/unplugged.

Control-plane VIP: **192.168.39.20** (floating, via kube-vip — see kube-vip.md).
Use this address for `kubectl`/API access instead of any single node's IP.

SSH: user `lykins`, key-based auth, same key across all three nodes.

## Network config

Static IPs are configured via classic Debian `ifupdown`, one file per node at
`/etc/network/interfaces.d/enp1s0`:

```
auto enp1s0
iface enp1s0 inet static
    address 192.168.39.1X/24
    gateway 192.168.39.1
    dns-nameservers 192.168.39.1
```

WiFi (`wlo1`) is disabled on all three nodes — its stanza in
`/etc/network/interfaces` is commented out and the interface is brought down.
It was previously the primary connection and its DHCP lease reassignment
mid-session is what broke the cluster (see History).

**Known fragility:** the `resolvconf` package is not installed, so
`dns-nameservers` in the ifupdown stanza has no effect. `/etc/resolv.conf` on
each node was set manually to `nameserver 192.168.39.1`. Since nothing manages
this file anymore (no dhcpcd/resolvconf hook), it should stay put — but if DNS
ever breaks after a node reboot, check this file first before anything else.

No DHCP reservations were set up on the router for `.10`–`.12`/`.20` — worth
doing to guarantee nothing else on the network is ever handed those addresses.

## k3s

- Version: `v1.36.4+k3s1` (pin `INSTALL_K3S_VERSION` to this on any reinstall
  to keep parity; check `k3s --version` on a live node before assuming this is
  still current)
- All three nodes are `server` role with embedded etcd (`--cluster-init` /
  `--server` join pattern, not agents)
- `mf-095` (192.168.39.10) is the node the other two joined against
  (`--server https://192.168.39.10:6443`). This is not structurally special
  post-join (etcd is symmetric HA) — it's just how the cluster was bootstrapped.
- `--tls-san 192.168.39.20` is set via `/etc/rancher/k3s/config.yaml` on all
  three nodes, so the API server cert covers the VIP. If the VIP address ever
  changes, this needs updating on all three nodes + `systemctl restart k3s`
  (rolling, one node at a time, verifying `kubectl get nodes` is healthy
  before moving to the next — don't restart all three together).
- Default k3s addons are in use: Traefik (ingress), CoreDNS, metrics-server,
  local-path-provisioner, built-in ServiceLB (Klipper) for LoadBalancer
  Services. None of these are customized beyond kube-vip (see kube-vip.md).
- Local etcd snapshots are taken automatically to
  `/var/lib/rancher/k3s/server/db/snapshots/` on every node (k3s default
  schedule/retention, currently ~5 kept, every 12h). These are the fallback if
  cluster state is ever lost — check they're still being produced
  periodically.

## Rebuilding a node or the whole cluster

If a node needs to be reinstalled: `k3s-uninstall.sh` (present on every server
node) fully removes k3s and its state. To rejoin:

```
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.36.4+k3s1 \
  INSTALL_K3S_EXEC="server --server https://192.168.39.10:6443 --node-ip <this-node-static-ip> --tls-san 192.168.39.20 --write-kubeconfig-mode 644" \
  K3S_TOKEN="<token from an existing server's /var/lib/rancher/k3s/server/node-token>" sh -
```

For the very first node of a fresh cluster, use `--cluster-init` instead of
`--server .../--token`. After any full rebuild, reapply
`manifests/kube-vip-*.yaml` (see kube-vip.md) — it is not auto-deployed.
