# Rebuild procedure (Proxmox)

Use this when you have a **fresh Proxmox VE install** and want to restore configuration from a snapshot taken earlier.

## Prerequisites

- Fresh (or clean) Proxmox VE installation.
- This framework copied onto the machine, including the snapshot you want to restore (e.g. `state/snapshots/2026-03-15-120000/`).

## Steps

1. **Copy the framework** (including `state/snapshots/<name>`) to the Proxmox host (e.g. via scp, USB, or git).

2. **Run restore:**
   ```bash
   cd proxmox-rebuild-framework
   chmod +x rebuild.sh
   sudo ./rebuild.sh --from-snapshot 2026-03-15-120000
   ```
   Use the snapshot directory name you used when taking the snapshot (timestamp or `--name`).

3. **Reboot** if you restored host config (GRUB, modules) so kernel and GPU passthrough settings take effect:
   ```bash
   sudo reboot
   ```

4. **Post-restore (manual):**
   - Re-add storage in the UI if this is a new machine (Datacenter → Storage).
   - Reattach or restore VM/CT disks (e.g. from vzdump or other backups); configs are restored but not disk images.
   - Adjust network if interface names differ from the original host.
   - Reconfigure backup jobs if storage paths or names changed.
   - If you use a cluster, follow Proxmox docs to rejoin nodes.

The script prints a **manual checklist** at the end; follow it for your setup.

## Restore only host config (no PVE cluster)

To restore only GRUB, modules, modprobe, and network (e.g. you do not want to overwrite PVE config):

```bash
./rebuild.sh --from-snapshot 2026-03-15-120000 --skip-step 02-restore-pve-config.sh
```

## Dry run

To see what would be done without writing:

```bash
./rebuild.sh --from-snapshot 2026-03-15-120000 --dry-run
```
