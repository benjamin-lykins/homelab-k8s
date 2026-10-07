# kube-vip (control-plane VIP)

Provides a floating IP, **192.168.39.20**, for the k3s API server so clients
don't need to target one specific node. Runs as a DaemonSet
(`kube-vip-ds`, namespace `kube-system`) on all three control-plane nodes,
using leader election (`plndr-cp-lock` lease) — whichever node is leader
ARP-announces `.20` on `enp1s0`.

Manifests: [manifests/kube-vip-rbac.yaml](manifests/kube-vip-rbac.yaml) and
[manifests/kube-vip-daemonset.yaml](manifests/kube-vip-daemonset.yaml).

## Not auto-deployed

These are applied directly via `kubectl apply -f` and live only as API objects
in etcd — they are **not** dropped into any node's
`/var/lib/rancher/k3s/server/manifests/` auto-deploy directory. This means a
full cluster rebuild (`k3s-uninstall.sh` + reinstall on all nodes) will *not*
bring kube-vip back automatically; you must reapply these two files manually
against a healthy cluster afterward.

## Critical config gotcha: `svc_enable` must stay `false`

kube-vip has two independent features, both controlled by env vars in the
DaemonSet: `cp_enable` (control-plane VIP, what we want) and `svc_enable`
(a `LoadBalancer`-Service IP controller, like MetalLB).

k3s already ships its own `LoadBalancer` Service controller (built-in
ServiceLB / Klipper), which sets a `LoadBalancer` Service's external IPs to
**all node IPs**. If `svc_enable: "true"` on kube-vip, it sees those existing
`LoadBalancer` Services (e.g. Traefik's) already carrying node IPs in
`status.loadBalancer.ingress` and "adopts" them — ARP-announcing every node's
own IP address as if it were a VIP it owns. This caused a real incident: the
elected kube-vip leader started answering ARP for all three node IPs plus the
real VIP, which intermittently hijacked traffic (including etcd raft
connections) meant for other nodes and looked like random cluster instability
until traced back to `ip -brief addr show` on the "wrong" node showing extra
`/32` addresses that didn't belong to it.

**Keep `svc_enable: "false"`** unless kube-vip's Service-IP feature is
deliberately wanted *and* k3s's built-in ServiceLB is disabled to match (via
`--disable servicelb` at install time) — never run both at once.

## If you need to change the VIP address

1. Update `address` in `manifests/kube-vip-daemonset.yaml` and reapply.
2. Update `tls-san` in `/etc/rancher/k3s/config.yaml` on **all three nodes**
   to the new address, then `systemctl restart k3s` one node at a time,
   checking `kubectl get nodes` is healthy before moving to the next (see
   cluster.md).
3. After reapplying kube-vip, immediately check `ip -brief addr show enp1s0`
   on all three nodes — only the elected leader should show the VIP as an
   extra `/32`; nothing should show another node's real IP. If it does,
   `kubectl delete daemonset kube-vip-ds -n kube-system` immediately and
   investigate before retrying.
