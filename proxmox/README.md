# Proxmox VE — Unattended Bare-Metal Provisioning

Zero-touch declarative provisioning pipeline for the **Lenovo ThinkCentre M700 Tiny** (`pve.dalles.it`) hypervisor.

## Components

- **`answer.toml`**: Unattended installer configuration with static management IP (`10.0.10.2/24`).
- **`first-boot.sh`**: Configures the VLAN-aware `vmbr0` bridge, disables NIC offloading, creates **VM 101** (OPNsense) with seed configs, and provisions **LXC 199** (Caddy).
- **`build-iso.sh`**: Compiles binary assets, bundles OPNsense/Caddy payloads, and generates `proxmox-ve-homelab-unattended.iso`.

## Disaster Recovery Workflow

1. Flash `proxmox-ve-homelab-unattended.iso` to a USB drive.
2. Plug the USB into the M700 Tiny (ensuring Port 2 trunk is connected to the switch).
3. Boot headless. The script provisions Proxmox, starts OPNsense on `startup order=1`, and launches Caddy on `startup order=2`.
