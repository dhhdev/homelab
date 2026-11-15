# Dalles Lab — Self-Hosted Homelab & Infrastructure-as-Code

Documentation, provisioning scripts, and network architecture for my self-hosted homelab running on a single-NIC **Router-on-a-Stick** topology with **Proxmox VE**, **OPNsense**, and a 3-node **OpenWrt `802.11s` mesh**.

More about my background and CV can be found at **[dalles.dk](https://dalles.dk)**.

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
│  Port 2: 802.1Q Trunk (VLAN 101 + VLAN 10, 20, 30, 40)   │
│  Port 3: 802.1Q Trunk (VLAN 10, 20, 30, 40)              │
└──────┬───────────────────────────────────────────┬───────┘
       │                                           │
       │ (Single-NIC Router-on-a-Stick Trunk)      │ (Trunk)
       ▼                                           ▼
[Lenovo M700 Tiny — Proxmox VE]              [wifi-main]
  └── [OPNsense VM]                          (D-Link M32 — Root AP)
       • WAN: PPPoE on VLAN 101                 /           \
       • VLAN 10: Infra (10.0.0.0/24)          /             \  (5 GHz 802.11s SAE Mesh)
       • VLAN 20: Trusted (10.0.20.0/24)      ▼               ▼
       • VLAN 30: Guest (10.0.30.0/24)  [wifi-first-floor] [wifi-boiler-room]
       • VLAN 40: IoT (10.0.40.0/24)
```

---

## VLAN Segmentation

| VLAN ID | Name | Subnet | Purpose & Isolation Policy |
| :--- | :--- | :--- | :--- |
| **VLAN 101** | `wan` | *ISP Public IP* | Carrier-tagged WAN trunk from Fiber ONT (Port 1) to OPNsense PPPoE WAN interface (Port 2). Isolated from all LAN ports. |
| **VLAN 10** | `infra` | `10.0.0.0/24` | Core infrastructure, hypervisor, switch management, and AP management (`uhttpd` + key-only `dropbear` bound exclusively here). |
| **VLAN 20** | `trusted` | `10.0.20.0/24` | Personal devices (`My WiFi Mesh` on 2.4 GHz & 5 GHz). Full WAN access and controlled access to internal services. |
| **VLAN 30** | `guest` | `10.0.30.0/24` | Guest network (`My WiFi Guest` on 2.4 GHz & 5 GHz) with Wi-Fi client isolation and WAN-only firewall rules. |
| **VLAN 40** | `iot` | `10.0.40.0/24` | Smart home and IoT devices (`My WiFi IoT` on 2.4 GHz only) with client isolation and strict firewall blocks to internal VLANs. |

---

## Hardware Stack

- **Hypervisor & Virtual Router:** Lenovo ThinkCentre M700 Tiny running **Proxmox VE** with an **OPNsense VM** (Kea DHCPv4, Unbound DNS, inter-VLAN firewalling).
- **Managed Switch:** TP-Link TL-SG108E Easy Smart Switch handling 802.1Q VLAN tagging and Router-on-a-Stick trunking over a single physical NIC.
- **Wireless Mesh:** 3x **D-Link EAGLE PRO AI M32 A1** (`mediatek/mt7622`) flashed with custom-built **OpenWrt** firmware operating as Dumb APs with `802.11s` SAE mesh backhaul and `usteer` (`802.11v/k`) roaming.

---

## Repository Structure

- **[`openwrt-d-link-m32-firmware/`](./openwrt-d-link-m32-firmware/)** — Custom OpenWrt package manifest, `uci-defaults` first-boot provisioning script (`uci-mesh-defaults.sh`), and D-Link emergency recovery flashing guide.

---

## Design Principles

- **Reproducible Configuration:** Nodes are provisioned via `uci-defaults` first-boot scripts rather than manual GUI clicks, allowing any node to be rebuilt or replaced cleanly.
- **Defense in Depth:** Management interfaces are isolated on VLAN `10`, SSH is disabled by default and restricted to public-key authentication, and unused router services (`dnsmasq`, `firewall4`, IPv6, PPPoE) are stripped at build time.
- **Resource Efficiency:** Built on compact, low-power hardware using 802.1Q trunking to eliminate unnecessary hardware purchases.
