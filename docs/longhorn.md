# Longhorn (replicated local-disk storage)

Distributed block storage built from each node's local disk, deployed via the
`longhorn/` Terraform component (`helm_release.longhorn`, chart
`longhorn/longhorn`). Gives replicated PersistentVolumes (default replica
count 3, one copy per node) so a PVC survives a single node going down,
without any dedicated storage hardware.

It runs alongside k3s's built-in `local-path-provisioner`, not in place of
it — `local-path-provisioner` stays the default StorageClass
(`persistence.defaultClass = false` in `longhorn/variables.tf`). Request
Longhorn explicitly with `storageClassName: longhorn` on a PVC.

## Node prerequisite: `open-iscsi`

Longhorn requires `open-iscsi` (specifically `iscsid` running) on every node
to attach volumes; it is **not** installed by k3s or by this Terraform.
Installed manually 2026-09-21 on all three nodes:

```
sudo apt-get install -y open-iscsi
sudo systemctl enable --now iscsid
```

This is host OS state, same category as the k3s install itself — not
tracked by Terraform. **After any node rebuild (see cluster.md), this must
be redone before Longhorn will work on that node again.**

## Storage layout: root filesystem, not the leftover data disks

`defaultDataPath` is `/var/lib/longhorn` on each node's root filesystem
(422–425G free on all three nodes as of 2026-09-21 — plenty of headroom).

`mf-095` and `mf-167` each also have a second, unmounted ~477G disk
(`/dev/vg_data/lv_data`) left over from before the 2026-09-18 cluster
rebuild — `ext4` on mf-095, `xfs` on mf-167, neither mounted, contents
unidentified. `mf-113` has no equivalent second disk, so the cluster isn't
symmetric across it. Longhorn was pointed at the root filesystem
deliberately to:

- avoid mounting/reformatting disks that may hold old data without first
  confirming what's on them
- keep all three nodes' storage contribution symmetric

If the leftover disks turn out to be safe to wipe, they could later be
mounted (e.g. at `/mnt/longhorn-extra`) and added as an additional Longhorn
disk on just those two nodes via `defaultSettings.disks` — but that's a
capacity increase, not required for Longhorn to work today.

## Verifying

```
kubectl get pods -n longhorn-system
kubectl get storageclass
```

The Longhorn UI can be reached by port-forwarding the `longhorn-frontend`
Service in `longhorn-system` — it isn't exposed via Ingress by this
Terraform.
