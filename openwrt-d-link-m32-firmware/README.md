# D-Link EAGLE PRO AI M32 A1 — Custom OpenWrt 802.11s Mesh & VLAN Firmware

Custom OpenWrt ImageBuilder configuration and provisioning script for a 3-node **D-Link EAGLE PRO AI M32 A1** (`mediatek/mt7622`) Dumb AP mesh setup backed by **OPNsense**.

## Architecture Overview

```text
[ISP Fiber ONT] ──(PPPoE VLAN 101)──► [TP-Link TL-SG108E Switch] ──Trunk──► [OPNsense VM (Proxmox)]
                                                                      ├── VLAN 10: Infra (10.0.0.0/24)
                                                                      ├── VLAN 20: Trusted (10.0.20.0/24)
                                                                      ├── VLAN 30: Guest (10.0.30.0/24)
                                                                      └── VLAN 40: IoT (10.0.40.0/24)
                                                                                    │
                                                     (5 GHz 802.11s SAE Mesh) ◄─────┴─────► [D-Link M32 Nodes]
```

- **Hardware:** 3x D-Link EAGLE PRO AI M32 A1 (`wifi-main`, `wifi-first-floor`, `wifi-boiler-room`) as Dumb Access Points with `802.11s` SAE mesh backhaul on 5 GHz (`Channel 36`, `HE40`).
- **Services:** OPNsense manages routing, DHCP/DNS, and firewall rules; `usteer` handles `802.11v/k` Wi-Fi roaming.
- **VLAN Segmentation (`br-lan`):** VLAN 10 (Management/Infra), VLAN 20 (Trusted Wi-Fi), VLAN 30 (Guest Wi-Fi, isolated), VLAN 40 (IoT Wi-Fi, 2.4 GHz isolated).

---

## 1. Building Custom Firmware Locally

Uses the official `openwrt/imagebuilder` Docker container (`--platform linux/amd64`) to compile images locally with injected environment variables.

### Build Steps
1. Copy and configure the environment file:
   ```bash
   cp openwrt-d-link-m32-firmware/.env.example openwrt-d-link-m32-firmware/.env
   ```
2. Execute the automated build script:
   ```bash
   ./openwrt-d-link-m32-firmware/build-firmware.sh
   ```
3. Compiled artifacts appear in `openwrt-d-link-m32-firmware/bin/`:
   - **SYSUPGRADE** (`*-squashfs-sysupgrade.bin`) for upgrading or reflashing existing OpenWrt nodes.
   - **RECOVERY** (`*-squashfs-recovery.bin`) for D-Link's built-in HTTP emergency recovery web UI (`192.168.0.1`) when flashing over stock firmware.
   - **TFTP** (`*-squashfs-tftp.bin`) for low-level U-Boot TFTP recovery when the HTTP recovery UI is unreachable.

### Package Manifest Summary
- **Included Packages:** Standard device profile packages plus `wpad-mesh-mbedtls` (WPA2/WPA3 and `802.11s`), `luci`/`luci-ssl`, `luci-app-attendedsysupgrade`, and `usteer`.
- **Stripped Packages:** `-dnsmasq`, `-firewall4 -nftables`, `-odhcp6c -odhcpd-ipv6only`, and `-ppp` (offloaded to OPNsense).

---

## 2. Flashing Nodes

### Option A: Standard OpenWrt Sysupgrade
1. In LuCI (`https://<node-ip>`), go to **System -> Backup / Flash Firmware**.
2. Select the `*-squashfs-sysupgrade.bin` image.
3. **Uncheck** *Keep settings and retain the current configuration*.
4. Click **Continue** and wait ~2–3 minutes for reboot and first-boot script execution.

### Option B: D-Link Emergency Recovery Mode
1. Unplug the M32 power cable and connect an Ethernet cable to **LAN 1** or **LAN 2**.
2. Set your computer's static IPv4 to `192.168.0.2` (Netmask: `255.255.255.0`).
3. Press and hold the **Reset** pinhole button, plug in the power cable, and hold for 10–15 seconds until the front LED flashes amber/orange.
4. Open `http://192.168.0.1` in a browser, upload the `*-squashfs-factory.bin` image, and flash.
5. Restore your computer to DHCP and connect the node to the VLAN 10 management trunk.

---

## 3. Post-Flash Verification

- **Web GUI:** Access via HTTPS (`https://<node-ip>`) using root and your `.env` password.
- **Identity:** Verify **Status -> Overview** shows the assigned hostname (`wifi-main`, etc.).
- **SSH:** `dropbear` is disabled by default; start it via **System -> Startup** if needed.

Part of [Dalles Lab](https://dalles.dk) — self-hosted infrastructure & IaC documentation.
