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

Installed 2026-11-12: **OMV 8.x ("synchrony")**, the release that targets
Debian 13.

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

So networking is being moved into OMV by hand instead: both interfaces keep
their current static IPs, with DNS `192.168.39.1` only. NetworkManager is then
disabled. *(In progress; this section will be updated with the final state.)*

### Access

- Web UI: `http://192.168.39.30/` (port 80). OMV's default login is `admin` /
  `openmediavault`. **Change it on first login.**
  *(Pending verification once the install finishes.)*
- SSH is unchanged (user `lykins`, key auth). The installer adds `lykins` to
  the `_ssh` group, which is what OMV uses to allow SSH logins.

### Storage

The three 512 GB USB SSDs are still blank. OMV has not set up any filesystem,
RAID, or share on them yet. Do that through the web UI (Storage → Disks /
File Systems / Shared Folders), and refer to the disks by-id, not as `sdX`.

## Status / open questions

- The intended role is a NAS (OMV). Storage layout (RAID level or separate
  disks, and filesystem) and what it will serve (SMB/NFS shares, a backup
  target for Longhorn or etcd snapshots) are not decided yet.
