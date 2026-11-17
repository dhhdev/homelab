# Proxmox VE — Unattended Bare-Metal & Guest Provisioning (`10.0.0.2`)

Declarative, zero-touch provisioning pipeline for the **Lenovo ThinkCentre M700 Tiny** (`pve.dalles.it`) hypervisor and its core infrastructure guests using the official `proxmox-auto-install-assistant`.

## Directory Layout

- **`answer.toml`** — Unattended Proxmox installer configuration (Danish locale/timezone, static `10.0.0.2/24` networking, LVM disk layout, SSH disabled).
- **`first-boot.sh`** — Runs automatically on first boot to configure the VLAN-aware `vmbr0` bridge, disable NIC hardware offloading, and create **VM 101** and **LXC 199**.
- **`build-iso.sh`** — Compiles the custom Caddy binary, renders OPNsense secrets locally, bundles the payload, and outputs a bootable `proxmox-ve-homelab-unattended.iso`.
- **`101-opnsense/`** — Minimal `config.xml.template` and secret-injection script for **VM 101** (`10.0.0.1`).
- **`199-caddy-proxy/`** — Custom `xcaddy` (`caddy-dns/cloudflare`) build and LXC provisioning scripts for **LXC 199** (`10.0.0.99`).

---

## Host Network Architecture (`vmbr0`)

Because all WAN and LAN traffic traverses a single physical NIC (`nic0`) in a **Router-on-a-Stick** setup:
- **Bridge Configuration:** `vmbr0` has `bridge-vlan-aware yes` (`bridge-vids 2-4094`) and carries the host management IP `10.0.0.2/24`.
- **VirtIO Stability Tuning:** Hardware offloading (`tso`, `gso`, `gro`, `tx`, `rx`) is disabled on the physical interface via `ethtool` on boot to prevent packet drops on OPNsense VirtIO interfaces.
- **Guest Interface Mapping:**
  - **VM 101 (`opnsense`):** `net0` attaches untagged to `vmbr0` as the LAN/VLAN trunk (`vtnet0`), while `net1` attaches to `vmbr0` with `tag=101` so Proxmox strips/tags carrier WAN frames directly for PPPoE (`vtnet1`).
  - **LXC 199 (`proxy`):** `eth0` attaches to `vmbr0` with static IP `10.0.0.99/24` so the internal reverse proxy boots independently of OPNsense DHCP.

---

## Building the Unattended Recovery ISO

1. **Populate OPNsense secrets** (never committed to Git):
   ```bash
   cp proxmox/101-opnsense/.env.example proxmox/101-opnsense/.env
   ```
2. **Populate Caddy Cloudflare DNS token** (never committed to Git):
   ```bash
   cp proxmox/199-caddy-proxy/caddy.env.example proxmox/199-caddy-proxy/caddy.env
   ```
3. **Set your Proxmox root password hash** inside `proxmox/answer.toml` (`openssl passwd -6`).
4. **Build the custom recovery ISO** (requires `proxmox-auto-install-assistant` and Go):
   ```bash
   ./proxmox/build-iso.sh /path/to/proxmox-ve_9.2-1.iso
   ```
5. Flash `proxmox/proxmox-ve-homelab-unattended.iso` to a USB drive.

---

## Disaster Recovery Workflow

1. Boot the replacement hardware from the unattended Proxmox USB drive.
2. Proxmox installs silently, configures `vmbr0`, creates **VM 101** (with `/conf/config.xml` auto-seeded onto a FAT32 seed disk), and provisions **LXC 199** with Caddy running.
3. Attach the OPNsense installer ISO to **VM 101**, boot it to complete the FreeBSD installation with the imported config, and install the `os-qemu-guest-agent` plugin.
