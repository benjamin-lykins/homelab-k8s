# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Terraform config that installs workloads onto a homelab Kubernetes cluster. Each component is a
self-contained Terraform root module in its own folder:

- `longhorn/` — the Longhorn Helm chart, giving replicated block storage built from each node's
  local disk. See `docs/longhorn.md`.
- `nfs/` — csi-driver-nfs plus the non-default `nfs` StorageClass, backed by the rasppi NAS
  (`192.168.39.30:/k8s`). See `docs/nfs.md`.
- `openbao/` — the OpenBao Helm chart in **dev mode**: a single in-memory, auto-unsealed server
  (plus the agent injector and UI Service). All secrets are lost whenever the `openbao-0` pod
  restarts; the root token is `var.dev_root_token` (default `root`).
- `n8n/` — n8n as plain Kubernetes resources (no Helm): a single-replica Deployment on SQLite with
  its data on a 5Gi `longhorn` PVC, exposed through a Traefik Ingress at
  `http://n8n.192.168.39.20.nip.io/`. The credential encryption key is a `random_password` kept
  in Terraform state — losing the state while keeping the PVC makes stored credentials unreadable.
  See `docs/n8n.md`.

## Commands

All commands run from inside a component folder (`longhorn/`, `nfs/`, `openbao/`, `n8n/`):

```
terraform init
terraform plan
terraform apply
terraform fmt
terraform validate
```

There is no test suite, lint config, or CI — validate changes with `terraform validate` / `terraform plan`.

## Configuration

- `homelab.yaml` (gitignored) is the kubeconfig used by both the `kubernetes` and `helm` providers
  (see `providers.tf`); it contains live cluster client-certificate credentials. Treat it and
  `terraform.tfvars`/`terraform.tfstate*` as secrets — never print their contents or paste them
  into commits, PRs, or chat. It must be regenerated from a live node
  (`/etc/rancher/k3s/k3s.yaml`, world-readable) after any cluster rebuild, with its `server:` field
  pointed at the control-plane VIP (`192.168.39.20`) instead of `127.0.0.1`.
- Each component needs its own copy of `homelab.yaml`.
- No secrets are required — `terraform.tfvars` is optional, for overriding a
  default in `variables.tf` (e.g. `replica_count`, `default_data_path`).

## Underlying cluster

`longhorn/` deploys *onto* an existing 3-node k3s cluster that isn't managed by this repo. See
`docs/` for its node inventory, network config, k3s bootstrap details, and the control-plane VIP
setup.

## Architecture notes

- `main.tf` creates the `longhorn-system` namespace (conditionally, via `create_namespace`) and
  installs `helm_release.longhorn`. `persistence.defaultClass` is left `false` so it doesn't
  conflict with k3s's built-in `local-path-provisioner`, which stays the default StorageClass —
  request Longhorn explicitly with `storageClassName: longhorn` on a PVC.
- Longhorn data lives on each node's root filesystem (`/var/lib/longhorn`), not the leftover
  unmounted data disks present on two of the three nodes — see `docs/longhorn.md` for why.
- Longhorn requires `open-iscsi`/`iscsid` running on every node; this is host OS state (like the
  k3s install itself), not tracked by Terraform, and must be reinstalled after any node rebuild.
