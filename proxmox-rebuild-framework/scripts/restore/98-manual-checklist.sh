#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/common.sh
source "$ROOT_DIR/lib/common.sh"

log_section "Manual checklist (post-restore)"

cat <<CHECKLIST

After restoring from snapshot:

1. Storage & disks
   - Re-add storage (Datacenter → Storage) if this is a fresh install.
   - VM/CT configs are restored but disk images are NOT. Reattach or
     restore VM disks from your backups (e.g. vzdump) or storage.

2. GPU passthrough
   - If you restored host-config (GRUB, modprobe, modules), reboot to load
     kernel and VFIO changes.
   - Verify IOMMU: dmesg | grep -e DMAR -e IOMMU
   - Verify VFIO: lspci -nnk and confirm GPU is bound to vfio-pci.

3. Network
   - If you restored network config, ensure interfaces match this host’s
     hardware (e.g. interface names may differ on new install).

4. Cluster
   - If this was a single node, no change. If you had a cluster, restore
     cluster config separately and rejoin nodes as per Proxmox docs.

5. Firewall & ACLs
   - VM firewall rules and datacenter firewall are in the snapshot;
     verify after restore.

6. Backups
   - Reconfigure backup jobs (Storage → Backup) if storage names changed.

CHECKLIST
log_info "Manual checklist printed above."
