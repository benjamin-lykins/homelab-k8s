# rasppi (192.168.39.30 / .31)

A standalone Raspberry Pi on the homelab LAN, running **OpenMediaVault (OMV)**
as a NAS. It is **not** a member of the k3s cluster (no k3s, Docker, or other
container runtime is installed). Both
`192.168.39.30` and `192.168.39.31` are this one host: `.30` is its wired NIC
and `.31` is its WiFi.

Facts below were gathered from the live host on 2026-11-12.

## Hardware

| | |
|---|---|
| Hostname | `rasppi` |
| Model | Raspberry Pi 4 Model B Rev 1.5 |
| CPU / RAM | 4 cores, 4 GB (3.7 GiB usable) |
| Boot / root | 32 GB microSD (`mmcblk0`): 512 MB `/boot/firmware`, ~29 GB `/` |
| Swap | 2 GB zram |
| Extra storage | 3 × 512 GB SSDs (model string `P3-512`), each in a USB-to-SATA enclosure (ASMedia ASM1153-family bridge) behind a USB 3 hub. They show up as `sda`/`sdb`/`sdc` and are **blank** — no partitions, no filesystems, not mounted. |

Device names `sda`–`sdc` are assigned in USB enumeration order and can change
between boots. If you ever partition or mount them, use UUIDs or the
`/dev/disk/by-id/` paths. The drive serials are 9240930073248,
9240930073258 and 9240930070516.

## OS

- Debian 13 (trixie), Raspberry Pi OS kernel `6.18.50+rpt-rpi-v8` (arm64)
- SSH: user `lykins`, key-based auth (the same key as the k3s nodes),
  passwordless `sudo`
- Before OMV, the only services were the base OS (`ssh`, `NetworkManager`,
  `wpa_supplicant`, `avahi-daemon`, `bluetooth`, `cron`, `systemd-timesyncd`).
  See "OpenMediaVault" below for what changed.

## Network

| Interface | IP | MAC | Route metric |
|---|---|---|---|
| `eth0` (wired) | 192.168.39.30/24 | d8:3a:dd:75:b1:44 | 100 (preferred) |
| `wlan0` (WiFi) | 192.168.39.31/24 | d8:3a:dd:75:b1:45 | 600 |

- Both interfaces are **static** (`ipv4.method manual`), gateway and DNS
  `192.168.39.1`.
- Unlike the k3s nodes, which use ifupdown, this Pi uses **NetworkManager**
  with netplan. Its connection profiles are `netplan-eth0` and
  `netplan-wlan0-<SSID>`, and NM writes them out under
  `/etc/netplan/90-NM-*.yaml`. Change settings with `nmcli`/`nmtui`, not
  by editing `/etc/network/interfaces`.
- `/etc/resolv.conf` is managed by NetworkManager.
- Both interfaces sit on the same /24, so the host has two default routes. The
  wired one wins on metric, and WiFi takes over if the cable is pulled.
  Inbound traffic to `.31` may be answered out of `eth0`, which is harmless on
  a flat LAN. If you see odd asymmetric-routing behavior, consider disabling
  WiFi as was done on the k3s nodes (see cluster.md).
- As with `.10`–`.12`/`.20`, there are no DHCP reservations on the router for
  `.30`/`.31`.

## OpenMediaVault

Installed 2026-11-12: **OMV 8.6.1** (`openmediavault 8.6.1-1`, the 8.x
"synchrony" release for Debian 13). The install took about 13 minutes and the
script exited cleanly.

### How it was installed

The installer was the OMV-Extras install script
(`https://raw.githubusercontent.com/OpenMediaVault-Plugin-Developers/installScript/master/install`,
script version 3.2.3). It was run as a transient systemd unit so an SSH drop
couldn't kill it:

```
sudo systemd-run --unit=omv-install \
  --property=StandardOutput=file:/var/log/omv-install-run.log \
  --property=StandardError=inherit \
  bash /home/lykins/omv-install -n
```

The full log is at `/var/log/omv-install-run.log` on the Pi.

The script also installs the OMV-Extras plugin repo and the `writecache`
plugin. That plugin cuts writes to the microSD (it was left enabled; the
default, no `-f`).

**Why `-n` (skip network setup).** By default the script moves networking from
NetworkManager into OMV's own config (systemd-networkd via netplan). Run as-is
on this Pi, that step would have:

- turned `wlan0` into **DHCP**, losing the static `.31`
- added `8.8.8.8` ahead of the router as a DNS server
- built the gateway from `ip route` output that has **two** default routes
  (one per interface), which could produce a malformed config

**Current network state:** networking is still handled entirely by
NetworkManager, exactly as described under "Network" above. OMV's network
config is empty, so its web UI's Network → Interfaces page shows nothing; don't
add interfaces there without planning the switchover. The OMV packages also
enabled `systemd-networkd` (no configs, so it manages nothing) and
`systemd-resolved`. `/etc/resolv.conf` still points only at `192.168.39.1`.

**`systemd-networkd-wait-online` is masked** (2026-11-12). With networkd
managing no interfaces, that unit always ran into its 2-minute timeout at boot.
Everything ordered after `network-online.target` waited with it, including
NFS, nginx (the web UI) and chrony, so `nfs-server` only came up about 127 s
into each boot. Just *disabling* it wasn't enough, because OMV's
`openmediavault-issue.service` has `Wants=systemd-networkd-wait-online`, which
starts it anyway. With it masked, `NetworkManager-wait-online` (already
enabled) is what `network-online.target` waits for. Boot now takes about 30 s,
with NFS up at about 23 s. **If you ever move networking into OMV, run
`sudo systemctl unmask systemd-networkd-wait-online` first.**

Moving the interfaces into OMV (static `.30`/`.31`, DNS `192.168.39.1` only,
then disabling and purging NetworkManager) has **not** been done. It's
optional, because OMV works fine with NetworkManager in charge. Do it only with
console access available, in case the switch drops both links.

### Access

- Web UI: `http://192.168.39.30/` (port 80, page title "openmediavault
  Workbench"). OMV's default login is `admin` / `openmediavault`. **Change it
  on first login.**
- SSH: user `lykins`, key auth, as before. OMV now owns `/etc/ssh/sshd_config`,
  so make SSH changes in the web UI (Services → SSH), not by editing the file.
  OMV's settings:
  - `AllowGroups root _ssh`: only members of `_ssh` (or root) can log in.
    The installer adds `lykins` to `_ssh`. **Any new SSH user must be added to
    `_ssh`.**
  - Keys are read from `~/.ssh/authorized_keys` *and* from OMV-managed keys
    (Users → Users → edit → Public keys, stored in
    `/var/lib/openmediavault/ssh/authorized_keys/<user>`).
  - OMV's defaults also allow **root login and password auth**
    (`PermitRootLogin yes`, `PasswordAuthentication yes`). Consider turning
    both off in Services → SSH.
- **Lockout gotcha seen during install:** OMV's `sshd_config` (with
  `AllowGroups _ssh`) is applied partway through the install, but `lykins` is
  only added to `_ssh` at the very end. For several minutes, every SSH login
  was refused with "Permission denied" / "Too many authentication failures".
  It fixed itself when the script finished. If you reinstall, run the script
  under `systemd-run` (as above) so it survives, and wait it out.

### Storage: mergerfs + SnapRAID

Set up 2026-11-12 through the web UI, using the `openmediavault-mergerfs`
(8.0.5) and `openmediavault-snapraid` (8.0.3) plugins. RAID was avoided on
purpose: the SSDs sit in USB enclosures behind one hub, and a brief USB reset
or power dip would drop a disk out of an md array and force a rebuild. With
mergerfs + SnapRAID every disk stays an independent ext4 filesystem.

| Role | Filesystem UUID (mounted at `/srv/dev-disk-by-uuid-<uuid>`) |
|---|---|
| SnapRAID `data1` + content file | `8fddbfbd-4bdc-4fb2-92d5-f46fc05bc12b` |
| SnapRAID `data2` + content file | `aa6f4fa7-9585-4dd4-b9af-936b3391b6fd` |
| SnapRAID parity | `ec837d52-e379-498a-a41b-ffc5c4c767b3` |

(`sdX` letters move between boots, so identify disks by these UUIDs.)

- **mergerfs pool `pool0`** at `/srv/mergerfs/pool0`, about 937 GB usable
  (`data1` + `data2`, create policy `pfrd`). Its options include
  `noforget,inodecalc=path-hash`, which mergerfs recommends when the pool is
  shared over NFS (without them clients can get "Stale file handle" errors).
  These options only take effect when the pool is remounted, so restart the
  pool or reboot after changing them. Check the live values with
  `sudo getfattr -n user.mergerfs.inodecalc /srv/mergerfs/pool0/.mergerfs`.
- **SnapRAID** array config is at `/etc/snapraid/array0.conf`. The
  `snapraid.content` files at the pool root are SnapRAID's index, shown
  through the pool. That's expected; they sit outside the shares.
- **Parity runs on a schedule, not in real time:** anything written since the
  last sync isn't protected yet. That suits this NAS's main jobs (backups,
  bulk data). It's a poor fit for live database files.
- **Nightly sync** is OMV's *Scheduled diff* (Services → SnapRAID → Settings →
  Scheduled diff), which runs `omv-snapraid-diff`, then `snapraid sync`, then
  an optional scrub. Its settings are in the "Diff script settings" section
  of the same page (written to `/etc/snapraid-diff.conf`). Don't add a
  separate Scheduled Task for the sync, because the threshold checks only
  apply through the diff script.
  - **Currently:** enabled, execution "Daily". OMV turns that into a
    `@daily` cron entry, so it runs at **00:00**. The Hour/Minute fields
    (set to 2:30) are ignored unless execution is "Certain date". The job
    runs `omv-snapraid-diff` against each `/etc/snapraid/omv-snapraid-*.conf`,
    which is why that file exists alongside `array0.conf` with identical
    contents. Don't delete it.
  - To find the job from a shell: it appears in
    `/etc/cron.d/openmediavault-userdefined` as a wrapper script under
    `/var/lib/openmediavault/cron.d/`, so grepping cron files for "snapraid"
    finds nothing.

### NFS shares (for the k3s cluster)

Two shared folders on `pool0`, exported over NFS (v3 to v4.2) to the three
k3s nodes only:

| Share | Server path | NFSv4 mount path | Used by |
|---|---|---|---|
| `k8s` | `/export/k8s` | `192.168.39.30:/k8s` | `nfs` StorageClass (csi-driver-nfs, see nfs.md) |
| `longhorn-backups` | `/export/longhorn-backups` | `192.168.39.30:/longhorn-backups` | Longhorn backup target |

- **Clients:** one entry per node (`192.168.39.10`, `.11`, `.12`), all
  `rw`, extra options `no_root_squash,subtree_check,insecure`.
  `no_root_squash` is required because the CSI driver creates and changes
  ownership of volume directories as root. That's also why access is limited
  to the node IPs: root on any allowed client effectively has root on these
  shares.
- **v4 paths drop the `/export` prefix.** OMV exports `/export` as the NFSv4
  pseudo-root (`fsid=0`), so v4 clients mount `/k8s`, not `/export/k8s`.
- Clients need `nfs-common` installed (now done on all three nodes; see nfs.md).

## Status / open questions

- Optional: move networking from NetworkManager into OMV (see "Current
  network state" above). Unmask `systemd-networkd-wait-online` first.
- Change the OMV `admin` password, and consider disabling root and password
  SSH logins.
- SnapRAID: consider a non-zero Delete threshold (currently `0`, meaning always sync). Send mail is
  on, but OMV email notifications are off, so reports go nowhere.
- `systemctl` shows "degraded" only because of three cosmetic
  `quotaon@srv-dev…` failures ("File exists"): OMV already turns quotas on at
  mount time.
- Possible later use: an extra copy of the k3s etcd snapshots.
