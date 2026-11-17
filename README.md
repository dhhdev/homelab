# Dalles Lab — Self-Hosted Homelab & Infrastructure-as-Code

> [!NOTE]
> Active development at this moment, it isn't completely ready yet. So it will change rapidly over the next couple of days. Right now my homelab works, but manually set up
on a flat network. (10.0.0.0/24)

Documentation, provisioning scripts, and network architecture for my self-hosted homelab running on a single-NIC **Router-on-a-Stick** topology with **Proxmox VE**, **OPNsense**, **Caddy**, and a 3-node **OpenWrt `802.11s` mesh**.

More about my background and CV can be found at **[dalles.dk](https://dalles.dk)**. I am looking for work and/or internship.

---

## Network Topology (Router-on-a-Stick)

```text
[ISP Fiber ONT]
       │
       │  (PPPoE over VLAN 101)
       ▼
┌──────────────────────────────────────────────────────────┐
│           TP-Link TL-SG108E Managed Switch               │
│  Port 1: WAN In (from ONT — VLAN 101)                    │
│  Port 2: 802.1Q Trunk (VLAN 101 + LAN / Infra Trunk)     │
│  Port 3: 802.1Q Trunk (LAN / Infra Trunk)                │
└──────┬───────────────────────────────────────────┬───────┘
       │                                           │
       │ (Single-NIC Router-on-a-Stick Trunk)      │ (Trunk)
       ▼                                           ▼
[Lenovo M700 Tiny — Proxmox VE (10.0.0.2)]   [wifi-main (10.0.0.10)]
  ├── [VM 101: OPNsense (10.0.0.1)]          (D-Link M32 — Root AP)
  │    • WAN: Telenor PPPoE on VLAN 101          /           \
  │    • LAN: 10.0.0.0/24 (Kea + Unbound)       /             \  (5 GHz 802.11s SAE Mesh)
  └── [LXC 199: Caddy Proxy (10.0.0.99)]       ▼               ▼
       • *.dalles.it (Cloudflare DNS-01) [wifi-first-floor] [wifi-boiler-room]
                                            (10.0.0.11)        (10.0.0.12)
```

---

## IPAM & VLAN Segmentation Roadmap

Currently, the live network runs on a flat **`10.0.0.0/24`** subnet (`VLAN 101` isolated for ISP PPPoE WAN), with full multi-VLAN firewall segmentation staged for rollout:

> [!IMPORTANT]
> This is the proposed structure I am aiming for to automate with this repo.

| VLAN ID | Name | Subnet | Purpose & Isolation Policy |
| :--- | :--- | :--- | :--- |
| **VLAN 101** | `wan` | *ISP Public IP* | Carrier-tagged WAN trunk from Fiber ONT (Port 1) to OPNsense PPPoE WAN interface (Port 2). Isolated from all LAN ports. |
| **VLAN 10** | `infra` | `10.0.10.0/24` | Core infrastructure, hypervisor (`10.0.10.2`), switch (`10.0.10.3`), reverse proxy (`10.0.10.99`), and AP management (`10.0.10.10–12`). |
| **VLAN 20** | `trusted` | `10.0.20.0/24` | Personal devices (`My WiFi Mesh` on 2.4 GHz & 5 GHz). Full WAN access and controlled access to internal services. |
| **VLAN 30** | `guest` | `10.0.30.0/24` | Guest network (`My WiFi Guest` on 2.4 GHz & 5 GHz) with Wi-Fi client isolation and WAN-only firewall rules. |
| **VLAN 40** | `iot` | `10.0.40.0/24` | Smart home and IoT devices (`My WiFi IoT` on 2.4 GHz only) with client isolation and strict firewall blocks to internal VLANs. |

---

## Hardware & Service Stack

- **Hypervisor:** Lenovo ThinkCentre M700 Tiny running **Proxmox VE** (`pve.dalles.it` — `10.0.10.2`) with a VLAN-aware Linux bridge (`vmbr0`) and VirtIO offload tuning.
- **Virtual Router (`VM 101`):** **OPNsense** (`opnsense.dalles.it` — `10.0.10.1`) handling ISP WAN, Kea DHCPv4 static reservations, and Unbound DNS (`*.dalles.it → 10.0.10.99`).
- **Internal Reverse Proxy (`LXC 199`):** Unprivileged Debian container running a custom **`xcaddy`** build (`caddy-dns/cloudflare` — `10.0.10.99`) terminating wildcard Let's Encrypt HTTPS for all internal `*.dalles.it` services without WAN port exposure.
- **Managed Switch:** TP-Link TL-SG108E (`switch.dalles.it` — `10.0.10.3`) handling 802.1Q VLAN tagging and Router-on-a-Stick trunking over a single physical NIC.
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
