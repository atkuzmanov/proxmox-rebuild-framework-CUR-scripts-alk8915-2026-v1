# Architecture (Proxmox Rebuild Framework)

This document describes how the Proxmox rebuild framework is structured and how snapshot and restore work.

## Design principles

- **Snapshot = export of config only** – No VM disks, no large files; only PVE config, cluster DB, and host customisation (GRUB, modules, network).
- **Restore = reapply on fresh install** – Restore host config first, then PVE cluster/config so a new Proxmox node matches your previous setup as far as config is concerned.
- **Idempotent steps** – Each script can be re-run; overwriting config is intentional on restore.
- **Clear boundaries** – Snapshot scripts only read and copy; restore scripts only write from a chosen snapshot.

## Execution flow

### Snapshot (snapshot.sh)

1. **00-preflight.sh** – Check we are on a Proxmox host (`/etc/pve`), require root or sudo.
2. **01-snapshot-pve-config.sh** – Backup `/var/lib/pve-cluster/config.db` and `/etc/pve` (as `etc-pve.tar`); write VM/CT ID lists under `pve-config/lists/`.
3. **02-snapshot-host-config.sh** – Backup GRUB, `/etc/modules`, `/etc/modprobe.d`, network (interfaces or netplan), optional initramfs modules.
4. **03-snapshot-manifest.sh** – Write `snapshot-manifest.txt` with timestamp, hostname, PVE version, kernel, VM/CT IDs.

Output: `state/snapshots/<name>/` containing `pve-config/`, `host-config/`, and `snapshot-manifest.txt`.

### Restore (rebuild.sh)

1. **00-preflight.sh** – Check snapshot directory exists and host is Proxmox; ensure root or sudo.
2. **01-restore-host-config.sh** – Restore GRUB, modules, modprobe.d, network from snapshot; run `update-grub` and optionally `update-initramfs -u`.
3. **02-restore-pve-config.sh** – Stop `pve-cluster`, restore `config.db`, start `pve-cluster` so `/etc/pve` is repopulated from the cluster DB.
4. **03-validate.sh** – Basic checks: `/etc/pve` exists, `pve-cluster` active, `storage.cfg` present.
5. **98-manual-checklist.sh** – Print post-restore tasks (storage, disks, reboot, network, cluster, backup jobs).

## What is not included

- **VM/container disk images** – Backed up separately (e.g. vzdump, storage replication).
- **ISOs and templates** – Stored on Proxmox storage; re-add storage and copy or re-download as needed.
- **Cluster membership** – Restoring `config.db` on a single node restores that node’s view; multi-node cluster recovery is per Proxmox documentation.

## Profiles

`profiles/<name>.env` can define optional variables (e.g. feature flags). Snapshot and rebuild both accept `--profile <name>` and source the file if present. Used for future extensions rather than required for basic snapshot/restore.

## Relation to Ubuntu/macOS frameworks

Same conventions: `lib/common.sh` and `lib/logging.sh`, step scripts in `scripts/snapshot/` and `scripts/restore/`, and a single entrypoint each for snapshot and rebuild. No package or chezmoi logic; this framework is only for Proxmox (and host) config capture and restore.
