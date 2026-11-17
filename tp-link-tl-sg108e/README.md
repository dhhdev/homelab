# TP-Link TL-SG108E — Managed Switch Configuration

Port-by-port VLAN documentation, disaster recovery workflow, and declarative OpenTofu/Terraform configuration for the **TP-Link TL-SG108E (Hardware V6.0)** Easy Smart Switch (`switch.dalles.it`).

## Device Details
- **Model & Hardware Revision:** TP-Link TL-SG108E `v6.0`
- **Firmware:** `1.0.0 Build 20250710 Rel.71008`
- **Management IP:** `10.0.10.3/24` (Kea DHCP reservation mapped to `60:15:6F:6E:92:7A`)
- **Reverse Proxy URL:** `https://switch.dalles.it` → `http://10.0.10.3`

---

## Live 802.1Q VLAN & PVID Port Matrix

> [!NOTE]
> An overall status can be found on the main README file.

Currently, **VLAN `101` (`ISP wan`)** isolates carrier PPPoE WAN frames between Port 1 and Port 2, while **VLAN `1` (`Default`)** carries the flat `10.0.0.0/24` LAN across Ports 2–8:

| Port | Connected Device | PVID | VLAN `1` (`Default`) | VLAN `101` (`ISP`) | Role |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Port 1** | ISP Fiber ONT | `101` | Not Member | **Tagged** | Carrier WAN In (`VLAN 101`) |
| **Port 2** | Lenovo M700 Tiny (`nic0` / `vmbr0`) | `1` | **Untagged** | **Tagged** | Router-on-a-Stick Trunk (WAN + LAN) |
| **Port 3** | `wifi-main` (D-Link M32 Root AP) | `1` | **Untagged** | Not Member | Wireless Mesh Root Uplink |
| **Port 4** | *Available* | `1` | **Untagged** | Not Member | LAN Access Port |
| **Port 5** | *Available* | `1` | **Untagged** | Not Member | LAN Access Port |
| **Port 6** | *Available* | `1` | **Untagged** | Not Member | LAN Access Port |
| **Port 7** | *Available* | `1` | **Untagged** | Not Member | LAN Access Port |
| **Port 8** | `Infra / Emergency Rescue Port` | `1` | **Untagged** | Not Member | LAN Access Port |

---

## Staged Multi-VLAN Rollout Matrix (Future)

When transitioning from the flat `10.0.0.0/24` LAN to full VLAN segmentation (`10, 20, 30, 40`), update the switch to match the OpenWrt `uci-mesh-defaults.sh` bridge tags:

| VLAN ID | Name | Port 1 (ONT) | Port 2 (Proxmox Trunk) | Port 3 (`wifi-main` Trunk) | Ports 4–7 (Access) | Port 8 (Emergency Rescue Port) |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **101** | `ISP wan` | **Tagged** | **Tagged** | Not Member | Not Member | Not Member |
| **10** | `infra` | Not Member | **Tagged** | **Tagged** | Not Member *(or Untagged for Infra)* | **Untagged** (`PVID 10`) |
| **20** | `trusted` | Not Member | **Tagged** | **Tagged** | **Untagged** (`PVID 20`) | Not Member |
| **30** | `guest` | Not Member | **Tagged** | **Tagged** | Not Member | Not Member |
| **40** | `iot` | Not Member | **Tagged** | **Tagged** | Not Member | Not Member |

---

## Disaster Recovery (Binary Backup Restore)

> [!IMPORTANT]
> I plan to streamline the recovery process further. Having files is kinda annoying, so in the future I will probably just run the script and have my own "config" file ready to rock as backup or similar.

Because the TL-SG108E does not expose SSH or an official REST API, always keep a local `.bin` backup exported from the web GUI (`*backup*` is automatically ignored by `.gitignore`):

> [!NOTE]
> The file is actually named config.cfg, but it is a binary file. I have no idea why TP-Link did it like that.

1. Log in to `https://switch.dalles.it` (or `http://10.0.10.3`).
2. Navigate to **System → System Tools → Backup and Restore**.
3. Click **Backup Config** to save a local `.bin` snapshot whenever VLANs change.
4. On a replacement switch (default IP `192.168.0.1`, `admin`/`admin`), upload the `.bin` file under **Restore Config** to restore all VLANs, PVIDs, and DHCP settings in one step.

---

## Optional OpenTofu / Terraform Automation

This folder also includes declarative configuration (`main.tf`) using the community [`davidlukac/tplinkeasysmart`](https://github.com/davidlukac/tplinkeasysmart) provider.

> [!NOTE]
> Just to be sure I have this for now - but in my testing it works as it should.

> [!CAUTION]
> (`Hardware v6.0`):** Because `tplinkeasysmart` relies on TP-Link's reverse-engineered UDP management protocol (primarily tested on V3–V5), always export a fresh `.bin` backup before running `tofu apply` / `terraform apply` against `v6.0` firmware.
