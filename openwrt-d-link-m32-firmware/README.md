# D-Link EAGLE PRO AI M32 A1 — Custom OpenWrt 802.11s Mesh & VLAN Firmware

Custom OpenWrt build configuration and first-boot provisioning script (`uci-mesh-defaults.sh`) for a 3-node **D-Link EAGLE PRO AI M32 A1** (`mediatek/mt7622`) Dumb AP mesh setup backed by **OPNsense**.

## Architecture Overview

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

- **Hardware:** 3x D-Link EAGLE PRO AI M32 A1 (`wifi-main`, `wifi-first-floor`, `wifi-boiler-room`)
- **Role:** Dumb Access Points with `802.11s` SAE mesh backhaul on 5 GHz (`Channel 36`, `HE40`)
- **Upstream Router:** OPNsense (handles routing, Kea DHCPv4, Unbound DNS, and firewall rules)
- **Wi-Fi Roaming:** `usteer` (`802.11v/k`) with MediaTek-tuned negative dBm thresholds
- **VLAN Segmentation (`br-lan` Bridge Filtering):**
  - **VLAN `10` (`10.0.0.0/24`):** Infrastructure & Management (br-lan.10); 802.11s mesh backhaul runs over raw br-lan trunk
  - **VLAN `20` (`10.0.20.0/24`):** `My WiFi Mesh` — Trusted Wi-Fi (2.4 GHz + 5 GHz)
  - **VLAN `30` (`10.0.30.0/24`):** `My WiFi Guest` — Guest Wi-Fi (2.4 GHz + 5 GHz, client isolation enabled)
  - **VLAN `40` (`10.0.40.0/24`):** `My WiFi IoT` — IoT Wi-Fi (2.4 GHz only, client isolation enabled)

## 1. Building the Custom Firmware Image

1. Go to [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/).
2. Search for and select **D-Link EAGLE PRO AI M32 A1** (`dlink_eagle-pro-ai-m32-a1`) and choose your desired OpenWrt release version.
3. Click **Customize installed packages and/or first boot script**.
4. Clear the **Installed Packages** box and paste this exact single-line package list:

`wpad-mesh-mbedtls luci luci-ssl luci-app-attendedsysupgrade usteer luci-app-usteer -dnsmasq -firewall4 -nftables -kmod-nft-offload -odhcp6c -odhcpd-ipv6only -ppp -ppp-mod-pppoe -wpad-basic-mbedtls`

5. Open `uci-mesh-defaults.sh`, fill in your passwords and SSH public key in Section `0`, and paste the entire script into **Script to run on first boot (uci-defaults)**.
6. Click **Request Build**. Once finished, download:
   - **SYSUPGRADE** (`*-squashfs-sysupgrade.bin`) for upgrading existing OpenWrt nodes.
   - **FACTORY** (`*-squashfs-factory.bin`) for flashing stock D-Link firmware or D-Link recovery mode.

### Package Manifest Breakdown

- **Automatically included by M32 device profile:** `base-files`, `busybox`, `dropbear`, `fstools`, `kmod-gpio-button-hotplug`, `kmod-leds-gpio`, `kmod-mt7622`, `kmod-mt7915-firmware`, `libc`, `libgcc`, `logd`, `mtd`, `netifd`, `opkg`/`apk`, `procd-ujail`, `uboot-envtools`, `uci`, `uclient-fetch`, `urandom-seed`, `urngd`, `ca-bundle`
- **Explicitly added:**
  - `wpad-mesh-mbedtls` — Full WPA2/WPA3 and `802.11s` SAE mesh support
  - `luci`, `luci-ssl` — HTTPS Web GUI (`uhttpd` + `mbedtls`)
  - `luci-app-attendedsysupgrade` — One-click future upgrades preserving custom packages
  - `usteer`, `luci-app-usteer` — `802.11v/k` Wi-Fi roaming daemon and LuCI interface
- **Explicitly stripped:**
  - `-wpad-basic-mbedtls` — Conflicts with `wpad-mesh-mbedtls`
  - `-dnsmasq` — Local DHCP/DNS server (handled by OPNsense)
  - `-firewall4 -nftables -kmod-nft-offload` — Local firewall/NAT (handled by OPNsense)
  - `-odhcp6c -odhcpd-ipv6only` — IPv6 DHCP client/server (IPv6 disabled)
  - `-ppp -ppp-mod-pppoe` — PPPoE/dial-up WAN support (unused)

## 2. Flashing Nodes

### Option A: Standard OpenWrt Sysupgrade (Existing OpenWrt Node)

> **Important:** `uci-defaults` first-boot scripts only execute on a clean configuration. Always **uncheck** *Keep settings and retain the current configuration*.

1. Log in to LuCI (`https://<node-ip>`) and go to **System -> Backup / Flash Firmware**.
2. Under **Flash new firmware image**, click **Flash image...** and select your `*-squashfs-sysupgrade.bin` file.
3. **Uncheck** *Keep settings and retain the current configuration*.
4. Click **Continue** and wait 2 to 3 minutes for the node to reboot and run `uci-mesh-defaults.sh`.

### Option B: D-Link Emergency Recovery Mode (Stock Firmware or Bricked Node)

Use this method to flash from stock D-Link firmware or recover a soft-bricked node:

1. **Unplug** the power cable from the D-Link M32.
2. Connect an Ethernet cable directly from your computer to **LAN 1** (or **LAN 2**) on the M32.
3. Configure a static IPv4 address on your computer's Ethernet adapter:
   - **IP Address:** `192.168.0.2`
   - **Subnet Mask:** `255.255.255.0`
   - **Gateway:** *(leave blank)*
4. Press and hold the recessed **Reset** pinhole button on the bottom/back of the M32 with a paperclip.
5. While still holding **Reset**, plug the power cable back in.
6. Continue holding **Reset** for **10 to 15 seconds** until the front status LED starts flashing **amber/orange** (or solid red/amber depending on revision), then release the button.
7. Open a browser (private/incognito window recommended) and navigate to `http://192.168.0.1`.
8. On the D-Link Emergency Firmware Upgrade page, click **Choose File**, select your `*-squashfs-factory.bin` image, and click **Upload** / **Upgrade**.
9. Wait **3 to 4 minutes** without unplugging power until the node finishes flashing and reboots into OpenWrt.
10. Set your computer's Ethernet adapter back to **DHCP (Automatic)** and ensure the node is connected to a trunk port carrying **VLAN `10` (`10.0.0.0/24`)** so it receives its management IP from OPNsense.

## 3. Post-Flash Verification

- **Web GUI Access:** Log in via HTTPS (`https://<node-ip>`) using user `root` and the `MASTER_ROOT_PASS` defined in `uci-mesh-defaults.sh`.
- **Node Identity:** Verify **Status -> Overview** displays the expected hostname (`wifi-main`, `wifi-first-floor`, or `wifi-boiler-room`). If `wifi-unknown-node` appears, check the detected MAC address in the **Description** field and add it to `uci-mesh-defaults.sh`.
- **SSH Access:** `dropbear` is disabled by default and pre-configured for key-only login (`/etc/dropbear/authorized_keys`). Start it on demand via **System -> Startup**.

Part of [Dalles Lab](https://dalles.dk) — self-hosted infrastructure & IaC documentation.
