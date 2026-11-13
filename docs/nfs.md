# NFS storage (csi-driver-nfs → rasppi)

Gives the cluster NFS-backed PersistentVolumes on the `rasppi` NAS
(`192.168.39.30`; see rasppi.md for the server side: OMV, the mergerfs pool,
SnapRAID, and the export settings). Deployed by the `nfs/` Terraform
component on 2026-11-12:

- `helm_release.csi_driver_nfs`: chart `csi-driver-nfs/csi-driver-nfs`
  4.13.6 in `kube-system`. The chart's own StorageClass is turned off
  (`storageClass.create = false`).
- `kubernetes_storage_class_v1.nfs`: StorageClass **`nfs`**, provisioner
  `nfs.csi.k8s.io`, server `192.168.39.30`, share `/k8s`, mount options
  `nfsvers=4.2,hard`. **Not** the default; `local-path` stays the default.

Request it with `storageClassName: nfs`. Each PV gets its own subdirectory
under the `k8s` share. `ReadWriteMany` works, so pods on different nodes can
share a volume.

## When to use it (vs Longhorn / local-path)

The NAS is a single Pi with nightly SnapRAID parity. It isn't replicated in
real time. Use `nfs` for:

- data that several pods or nodes need at once (`ReadWriteMany`)
- bulk or media data, and anything that changes rarely

Avoid it for databases or other write-heavy files. Writes since the last
nightly sync aren't covered by parity, and if the Pi goes down every pod
using the volume hangs. (The `hard` mount option makes I/O wait for the
server instead of failing.) Use Longhorn for those, once it's deployed.

## Deleting volumes: `onDelete = archive`

The StorageClass has `reclaimPolicy: Delete`, with the driver parameter
`onDelete: archive`. Deleting a PVC therefore *renames* its directory on the
NAS to `archived-pvc-<uid>` instead of removing it, so a mistaken delete loses
nothing. Archived directories stay until removed by hand:

```
ssh lykins@192.168.39.30 'sudo ls /srv/mergerfs/pool0/k8s/'
ssh lykins@192.168.39.30 'sudo rm -rf /srv/mergerfs/pool0/k8s/archived-pvc-<uid>'
```

Change this with `on_delete` / `reclaim_policy` in `nfs/variables.tf`.

## Node prerequisite: `nfs-common`

Each node needs `nfs-common` (the NFS mount helper) or pods fail to mount NFS
volumes. Installed 2026-11-12 on all three nodes:

```
sudo apt-get install -y nfs-common
```

Like `open-iscsi` for Longhorn, this is host OS state that Terraform doesn't
track. **Redo it after any node rebuild.**

## Verification done at install

A ReadWriteMany PVC mounted by a pod on each of the three nodes; each pod
wrote a file, and all three files were visible from every pod and on the NAS.
Deleting the PVC produced `archived-pvc-…` on the NAS as expected, and the
test data was then removed.

## Longhorn backup target

The NAS also has a `longhorn-backups` share. `longhorn/variables.tf` sets
`backup_target = "nfs://192.168.39.30:/longhorn-backups"` (passed as the
chart value `defaultBackupStore.backupTarget`). The share was tested
read/write over NFSv4.2 from a node.

**As of 2026-11-12, Longhorn itself is not deployed.** The `longhorn/`
component has no Terraform state and there's no `longhorn-system` namespace.
The backup target takes effect when it's next applied.
