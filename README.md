> [!NOTE]
> I am looking for work and/or internship. More about my background and CV can be found at **[dalles.dk](https://dalles.dk)** and on **[LinkedIn](https://www.linkedin.com/in/daniel-h-hemmingsen/)**.

# Zero-Touch Modular Homelab

Declarative, Infrastructure-as-Code (IaC) driven deployment pipeline for a fully automated, headless homelab. Designed for reproducible disaster recovery and relocation without GUI interaction.

## Network Topology & Router-on-a-Stick Model

```text
[ ISP Fiber ONT ] (Port 1: VLAN 101 Tagged)
       │
       ▼
[ TP-Link TL-SG108E Switch ] ──(Port 8: Untagged VLAN 10 — Emergency Rescue)
       │
       ├─► [ Lenovo M700 Tiny ] (Port 2: Trunk VLAN 10, 20, 30, 40, 101)
       │     └─► Proxmox VE (Host IP: 10.0.10.2/24)
       │           ├─► VM 101: OPNsense Router-on-a-Stick (Gateway: 10.0.10.1)
       │           │     ├─► VLAN 10: Infra / Management
       │           │     ├─► VLAN 20: Trusted LAN
       │           │     ├─► VLAN 30: Guest Network
       │           │     └─► VLAN 40: IoT Network (WAN Blocked)
       │           └─► LXC 199: Caddy Reverse Proxy (IP: 10.0.10.99)
       │
       └─► [ D-Link M32 Root Mesh AP ] (Port 3: Trunk VLAN 10, 20, 30, 40)
             │
             ├── 802.11s Wireless Mesh Backhaul
             │         │
             │         ▼
             │   [ D-Link M32 Satellite Node ]
             │
             ├─► SSID: Trusted Wi-Fi  ──► Tagged VLAN 20
             ├─► SSID: Guest Wi-Fi    ──► Tagged VLAN 30 (Client Isolation)
             └─► SSID: IoT Smart Home ──► Tagged VLAN 40 (Isolated)
```

## VLAN Segmentation Matrix

- **VLAN 101 (`ISP wan`):** Isolated carrier PPPoE trunk between ONT and OPNsense.
- **VLAN 10 (`infra`):** Hypervisor management, switch management, and core container services (`10.0.10.0/24`).
- **VLAN 20 (`trusted`):** Primary personal devices and trusted LAN.
- **VLAN 30 (`guest`):** Isolated guest wireless access.
- **VLAN 40 (`iot`):** Restricted smart-home devices (WAN blocked).

## Deployment Sequence

1. **Switch First:** Apply OpenTofu configurations in `tp-link-tl-sg108e/` to establish trunking and PVIDs.
2. **Hypervisor Second:** Build and boot the unattended Proxmox ISO on the M700 Tiny while it is connected to port 2. OPNsense and Caddy provisions automatically on first boot.
3. **Mesh Last:** Build and flash custom OpenWrt firmware onto the D-Link M32 nodes and plug one of them into port 3.

## Hardware & Service Stack

- **Hypervisor:** Lenovo ThinkCentre M700 Tiny running **Proxmox VE** (`pve.dalles.it` — `10.0.10.2`) with a VLAN-aware Linux bridge (`vmbr0`) and VirtIO offload tuning.
- **Virtual Router (`VM 101`):** **OPNsense** (`opnsense.dalles.it` — `10.0.10.1`) handling ISP WAN, Kea DHCPv4 static reservations (with assigned hostname.internal, for services that could benefit from it), and Unbound DNS.
- **Internal Reverse Proxy (`LXC 199`):** Unprivileged Debian container running a custom **`xcaddy`** build (`caddy-dns/cloudflare` — `10.0.10.99`) terminating wildcard Let's Encrypt HTTPS for all internal `*.dalles.it` services without WAN port exposure.
- **Managed Switch:** TP-Link TL-SG108E (`switch.dalles.it` — `10.0.10.3`) handling 802.1Q VLAN tagging and Router-on-a-Stick trunking over a single physical NIC to my **Proxmox VE**.
- **Wireless Mesh:** 3x **D-Link EAGLE PRO AI M32 A1** (`mediatek/mt7622` — `10.0.10.10–12`) flashed with custom-built **OpenWrt** firmware operating as Dumb APs with `802.11s` SAE mesh backhaul and `usteer` (`802.11v/k`) roaming.

---

## Repository Structure

- **[`proxmox/`](./proxmox/)** — Unattended Proxmox VE bare-metal installer (`answer.toml`, `first-boot.sh`, `build-iso.sh`) for zero-touch disaster recovery.
- **[`proxmox/101-opnsense/`](./proxmox/101-opnsense/)** — Minimal, secret-free OPNsense `config.xml.template` and `envsubst` rendering script.
- **[`proxmox/199-caddy-proxy/`](./proxmox/199-caddy-proxy/)** — Custom `xcaddy` build script, `Caddyfile`, systemd overrides, and idempotent LXC provisioning script.
- **[`tp-link-tl-sg108e/`](./tp-link-tl-sg108e/)** — 802.1Q VLAN/PVID port matrix, disaster recovery guide, and declarative OpenTofu/Terraform config.
- **[`openwrt-d-link-m32-firmware/`](./openwrt-d-link-m32-firmware/)** — Custom OpenWrt package manifest, `uci-defaults` first-boot provisioning script (`uci-mesh-defaults.sh`), and D-Link emergency recovery flashing guide.

---

## Design Principles

- **Zero-Touch Bare-Metal Recovery:** Every layer—from Proxmox's automated installer ISO and OPNsense's XML seeding to OpenWrt's `uci-defaults`—is codified so failed hardware can be rebuilt cleanly without manual GUI clicking.
- **Defense in Depth:** Management interfaces are isolated internally with zero WAN exposure, SSH is disabled by default across nodes and hypervisor, and unused services are stripped at build time.
- **Resource Efficiency:** Built on compact, low-power hardware using 802.1Q trunking to eliminate unnecessary hardware purchases.
