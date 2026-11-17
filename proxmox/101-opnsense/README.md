# OPNsense Configuration (`VM 101` — `10.0.0.1`)

Declarative, minimal `config.xml` template and rendering script for the **OPNsense** virtual router running on Proxmox VE (`VM 101`).

## Key Configuration Details
- **WAN (`pppoe0` on `vtnet1`):** Telenor PPPoE over VLAN 101 (tagged at the Proxmox `vmbr0` bridge level).
- **LAN (`vtnet0`):** Static gateway `10.0.0.1/24` with hardware checksum, TSO, LRO, and VLAN hardware filtering disabled for VirtIO stability.
- **Kea DHCPv4:** Dynamic pool `10.0.0.100–250` plus static reservations for core infrastructure (`pve`, `switch`, `wifi-*`, and `proxy`).
- **Unbound DNS:** Forwards upstream queries to Cloudflare (`1.1.1.1`, `1.0.0.1`), registers static DHCP hostnames under `.internal`, and resolves wildcard `*.dalles.it` to `10.0.0.99`.
- **Hardening:** Root account disabled, SSH disabled (`noauto=1`), IPv6 disabled, and WebGUI restricted to internal networks using local database authentication.

## Generating `config.xml` Locally
1. Copy the environment template and populate your secrets:
   ```bash
   cp opnsense/.env.example opnsense/.env
   ```
2. Render the final `config.xml`:
   ```bash
   ./opnsense/render-config.sh
   ```

## Disaster Recovery / Unattended Restore
To restore onto a fresh OPNsense VM (`VM 101`):
1. Place the rendered `config.xml` inside a `/conf/` directory on a small FAT32 disk image or USB drive (e.g., `/conf/config.xml`).
2. Attach the OPNsense installer ISO and the config disk to `VM 101` and boot.
3. OPNsense automatically imports `/conf/config.xml` during boot before installation begins.
4. Once installed, install the QEMU Guest Agent plugin (`os-qemu-guest-agent`) via **System → Firmware → Plugins** (or `pkg install -y os-qemu-guest-agent`).
