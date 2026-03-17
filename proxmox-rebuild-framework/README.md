# Proxmox Rebuild Framework

A snapshot-and-restore framework for Proxmox VE that lets you **save** all custom configuration (including GPU passthrough, VM/CT configs, storage, firewall) and **restore** it on a fresh Proxmox install—without backing up large VM disks or ISO files.

## What it does

- **Snapshot** (on your current Proxmox host): Saves PVE config (cluster DB, `/etc/pve`), VM/CT configs, storage definitions, firewall, and host config (GRUB, kernel modules, modprobe, network) into a timestamped folder under `state/snapshots/`.
- **Restore** (after a fresh Proxmox install): Restores host config and PVE config from a chosen snapshot so you get back VM definitions, GPU passthrough settings, and customisations. You then reattach or restore VM disks separately (e.g. from vzdump or storage).

**Not included:** VM disk images, large ISOs, or backup archives. Only configuration and small metadata.

## Quick start

### 1. Take a snapshot (on existing Proxmox)

```bash
# Clone or copy this repo onto your Proxmox server, then:
chmod +x snapshot.sh rebuild.sh
sudo ./snapshot.sh
# Or with a custom name:
./snapshot.sh --name my-before-upgrade
# Or write snapshots somewhere else (e.g. a mounted disk/NFS share):
./snapshot.sh --output-dir /mnt/backups/pve-snapshots --name my-before-upgrade
# Paths with spaces are supported; just quote them:
./snapshot.sh --output-dir "/mnt/backups/Proxmox Snapshots" --name "before upgrade"
# If you accidentally paste a backslash before spaces, the scripts normalize '\ ' to ' ':
./snapshot.sh --output-dir "/mnt/backups/Proxmox\ Snapshots" --name "before upgrade"
# You can also use --flag=value style:
./snapshot.sh --output-dir="/mnt/backups/pve-snapshots" --name=my-before-upgrade
```

Snapshot is written to `state/snapshots/<timestamp-or-name>/`.

### 2. Restore after a fresh install

```bash
# Copy the framework (including state/snapshots/) to the new/fresh Proxmox host, then:
./rebuild.sh --from-snapshot 2026-03-15-120000
# Or the name you used:
./rebuild.sh --from-snapshot my-before-upgrade
# Or restore from a custom snapshots location:
./rebuild.sh --snapshot-root /mnt/backups/pve-snapshots --from-snapshot my-before-upgrade
# Paths with spaces are supported; just quote them:
./rebuild.sh --snapshot-root "/mnt/backups/Proxmox Snapshots" --from-snapshot "before upgrade"
# If you accidentally paste a backslash before spaces, the scripts normalize '\ ' to ' ':
./rebuild.sh --snapshot-root "/mnt/backups/Proxmox\ Snapshots" --from-snapshot "before upgrade"
# You can also use --flag=value style:
./rebuild.sh --snapshot-root="/mnt/backups/pve-snapshots" --from-snapshot=my-before-upgrade
```

Use `sudo ./rebuild.sh` if you need root for PVE cluster restore. Reboot after restore if you restored GRUB/kernel (e.g. GPU passthrough) config.

## Directory layout

```text
proxmox-rebuild-framework/
├── README.md
├── snapshot.sh              # Take a snapshot
├── rebuild.sh               # Restore from a snapshot
├── lib/
│   ├── common.sh
│   └── logging.sh
├── scripts/
│   ├── snapshot/            # Snapshot steps
│   │   ├── 00-preflight.sh
│   │   ├── 01-snapshot-pve-config.sh
│   │   ├── 02-snapshot-host-config.sh
│   │   └── 03-snapshot-manifest.sh
│   └── restore/             # Restore steps
│       ├── 00-preflight.sh
│       ├── 01-restore-host-config.sh
│       ├── 02-restore-pve-config.sh
│       ├── 03-validate.sh
│       └── 98-manual-checklist.sh
├── profiles/
│   └── default.env          # Optional profile
├── state/
│   └── snapshots/           # Snapshot output (timestamp or --name)
└── logs/
```

## What gets snapshotted

| Category | Contents |
|----------|----------|
| **PVE config** | `/var/lib/pve-cluster/config.db`, `/etc/pve` (VM/CT configs, storage.cfg, firewall, ACLs, etc.) |
| **Host (GPU passthrough etc.)** | `/etc/default/grub`, `/etc/modules`, `/etc/modprobe.d/`, `/etc/network/interfaces` or `/etc/netplan/`, `/etc/systemd/`, `/etc/zfs/`, `/etc/nut/`, optional initramfs modules |
| **Diagnostics (informational)** | `diagnostics/*.txt` (ZFS status, ZFS properties, storage.cfg copy, pveversion -v, proxmox-boot-tool status, etc.) |
| **APT state** | `apt/dpkg-selections.txt`, `apt/apt-manual-packages.txt` (optional restore of filtered manual packages) |
| **Optional full /etc** | `host-config/etc-full.tar.gz` (enabled with `SNAPSHOT_ETC_ALL=1`; restore with `RESTORE_ETC_ALL=1`) |
| **Manifest** | Timestamp, hostname, PVE version, list of VM/CT IDs |

## What you do manually after restore

1. **Storage & disks** – Re-add storage if fresh install; reattach or restore VM disks (vzdump, etc.).
2. **Reboot** – If host config (GRUB/modules) was restored, reboot so IOMMU/VFIO and GPU passthrough take effect.
3. **Network** – Adjust interface names if hardware differs from the snapshot host.
4. **Cluster** – If you had a cluster, follow Proxmox docs to rejoin nodes; single-node restore is straightforward.
5. **Backup jobs** – Reconfigure backup jobs if storage names or paths changed.

See the printed manual checklist at the end of `rebuild.sh` for the full list.

## Options

### Snapshot

```bash
./snapshot.sh [--profile <name>] [--name <snapshot-dir-name>] [--output-dir <path>] [--dry-run]
```

- `--name` – Use a fixed directory name instead of a timestamp (e.g. `my-before-upgrade`).
- `--profile` – Load `profiles/<name>.env` if present (for future use).
- `--output-dir` – Base directory for snapshots (default: `state/snapshots/`).
- `--dry-run` – Log what would be done without writing.
- `SNAPSHOT_ETC_ALL=1` – Also archive (almost) all of `/etc` into `host-config/etc-full.tar.gz` (contains secrets; use with care).

### Rebuild (restore)

```bash
./rebuild.sh --from-snapshot <name> [--snapshot-root <path>] [--profile <name>] [--only-step <script>] [--skip-step <script>] [--dry-run]
```

- `--from-snapshot` – Snapshot directory name under `state/snapshots/` (required).
- `--snapshot-root` – Base directory where snapshots live (default: `state/snapshots/`).
- `--only-step` / `--skip-step` – Run only one restore script or skip specific ones.
- Use `sudo ./rebuild.sh` when restoring PVE cluster config so `config.db` and `pve-cluster` can be updated.
- `RESTORE_ETC_ALL=1` – Extract `host-config/etc-full.tar.gz` over `/etc` (dangerous on mismatched hardware/installs; use with care).
- `RESTORE_APT_PACKAGES=true` – Install filtered APT packages from `apt/apt-manual-packages.txt` on restore (see `apt/apt-manual-packages-filtered.txt`).

## Requirements

- Proxmox VE host (script checks for `/etc/pve`).
- Root or sudo for reading `/etc/pve`, `/var/lib/pve-cluster`, and for writing host and PVE config on restore.
- Bash, `tar`, `cp`, `date` (and `sudo` if not root).

## Relation to other frameworks

This follows the same idea as the **ubuntu-rebuild-framework** and **macos-rebuild-framework**: idempotent scripts, clear steps, and a small lib for logging and helpers. Here the “export” step is **snapshot** (capture Proxmox + host config) and the “rebuild” step is **restore** (apply that config on a fresh install), without handling packages or dotfiles.
