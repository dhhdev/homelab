#!/bin/sh
# First-boot provisioning script (uci-defaults) for D-Link EAGLE PRO AI M32 A1.
# See README.md for the required Firmware Selector package list and build/flashing instructions.
# This method is used with the recovery "hack" method, where you put the device into recovery mode.
# See README.md for a guide on doing this. You might have a version that does not support this and
# in that case you would actually have to open up the device, so keep that in mind.

# ==============================================================================
# 0. Master Credentials, SSH Key & Wi-Fi Passwords
# ==============================================================================

# IMPORTANT!
# These variables have to be changed to your specific needs.
# I have tried to make it somewhat universal, but do keep in mind that specifically section 1
# is very specific to my use case.

# The password you use to log into the WEB GUI interface, remember to change this.
MASTER_ROOT_PASS=""

# Set timezone and POSIX DST rule (currently configured for Denmark / Europe/Copenhagen).
# To change this for your own country, look up your matching 'zonename' and POSIX 'timezone'
# The list: https://github.com/openwrt/luci/blob/master/modules/luci-lua-runtime/luasrc/sys/zoneinfo/tzdata.lua
# First field is zonename, the second is timezone.
# (Alternatively, select your timezone in LuCI -> System -> System and check /etc/config/system)
ZONENAME="Europe/Copenhagen"
TIMEZONE="CET-1CEST,M3.5.0,M10.5.0/3"
# Set LuCI Web GUI clock format to 24-hour time ('h23' = 00:00-23:59, 'h12' = 12-hour AM/PM)
HOUR_CYCLE="h23"
# Log size in KiB
LOG_SIZE="128"

# If not changed and kept like it is, logging in with root and MASTER_ROOT_PASS will grant
# access to SSH. You will have to activate dropbear (start) which is the SSH server through the WEB GUI.
# If the public key is provided, it disables log in with password altogether, but the default behaviour
# is still to not have dropbear (SSH server) running.
SSH_PUBLIC_KEY=""

# Trusted (main) WiFi (VLAN 20)
# Devices like your phones, computers etc.
WIFI_TRUSTED_SSID="My WiFi Mesh"
WIFI_TRUSTED_PASS="CHANGE_ME"

# Guest WiFi (VLAN 30)
# If you are lucky to have guests around your house, provide them with this.
WIFI_GUEST_SSID="My WiFi Guest"
WIFI_GUEST_PASS="CHANGE_ME"

# IoT WiFi (VLAN 40)
# I do not need a light bulb to be able to talk to the (WAN) internet.
WIFI_IOT_SSID="My WiFi IoT"
WIFI_IOT_PASS="CHANGE_ME"

# Mesh backhaul (5GHz) wireless password, all nodes need the same to talk to each other.
MESH_BACKHAUL_ID="my-mesh-backhaul"
MESH_BACKHAUL_PASS="CHANGE_ME"

# Important: It follows this https://git.kernel.org/pub/scm/linux/kernel/git/sforshee/wireless-regdb.git/tree/db.txt
# Different countries might have different rules and regulations.
COUNTRY_CODE="DK"

# Change the Web GUI password/root user password
# It isn't possible to add/remove users in this system. It is built like this to make the
# firmware as small as possible.
if [ -n "$MASTER_ROOT_PASS" ]; then
  printf "%s\n%s\n" "$MASTER_ROOT_PASS" "$MASTER_ROOT_PASS" | passwd root >/dev/null 2>&1
fi

# ==============================================================================
# 1. Node Identification via Factory MAC Address
# IMPORTANT: This section is only important to my setup.
# You can still run this, the node you are flashing will just have some default
# values and be named "wifi-unknown-node".
# ==============================================================================
NODE_MAC=$(cat /sys/class/ieee80211/phy0/macaddress /sys/class/ieee80211/phy1/macaddress /sys/class/net/br-lan/address 2>/dev/null | grep -v '00:00:00:00:00:00' | head -n1 | tr 'a-f' 'A-F')

case "$NODE_MAC" in
"64:29:43:92:4E:EA" | "64:29:43:92:4E:EB")
  HOSTNAME="wifi-main"
  DESCRIPTION="The main base station of my WiFi mesh setup"
  CH_2G="1"
  TX_5G="20"
  MIN_CONNECT_SNR="-82"
  BLOCK_MAC=""
  ;;
"64:29:43:92:4E:E0" | "64:29:43:92:4E:E1")
  HOSTNAME="wifi-first-floor"
  DESCRIPTION="First floor satellite node of my WiFi mesh setup"
  CH_2G="6"
  TX_5G="17"
  MIN_CONNECT_SNR="-75"
  # My Mac Mini M1 has a tendency to wander up to this node and I do not want this.
  BLOCK_MAC="4C:20:B8:E9:0A:54"
  ;;
"64:29:43:92:4E:F4" | "64:29:43:92:4E:F5")
  HOSTNAME="wifi-boiler-room"
  DESCRIPTION="Boiler room satellite node of my WiFi mesh setup"
  CH_2G="11"
  TX_5G="20"
  MIN_CONNECT_SNR="-82"
  BLOCK_MAC=""
  ;;
*)
  HOSTNAME="wifi-unknown-node"
  DESCRIPTION="Unrecognized MAC (${NODE_MAC:-unknown}) - check node assignment"
  CH_2G="1"
  TX_5G="20"
  MIN_CONNECT_SNR="-82"
  BLOCK_MAC=""
  ;;
esac

# Enforce https, this only runs the first time when flashing the firmware
if [ -f /etc/config/uhttpd ]; then
  uci set uhttpd.main.redirect_https='1'
  uci commit uhttpd
fi

# ==============================================================================
# 2. System, Timezone & Logging
# ==============================================================================
# Set up device/node specific settings like hostname, timezone and so on.
uci set system.@system[0].hostname="$HOSTNAME"
uci set system.@system[0].description="$DESCRIPTION"
uci set system.@system[0].zonename="$ZONENAME"
uci set system.@system[0].timezone="$TIMEZONE"
uci set system.@system[0].clock_hourcycle="$HOUR_CYCLE"
uci set system.@system[0].log_size="$LOG_SIZE"
uci commit system

# ==============================================================================
# 3. Dumb AP Network & Bridge VLAN Filtering (VLAN 10, 20, 30, 40)
# ==============================================================================
uci set network.globals.packet_steering='1'

# Delete all networks
uci delete network.wan 2>/dev/null
uci delete network.wan6 2>/dev/null
uci delete network.lan 2>/dev/null

# Create br-lan (bridged lan1, lan2 and wan ports)
uci set network.@device[0].name='br-lan'
uci set network.@device[0].type='bridge'
# Enable VLAN filtering
uci set network.@device[0].vlan_filtering='1'
# Disable IPv6
uci set network.@device[0].ipv6='0'
# Delete default ports attached to br-lan bridge
uci delete network.@device[0].ports 2>/dev/null

# Add networks reflecting the physical ports on the device/node, but bridge them together.
# In other words, it doesn't matter which port you use for the actual WAN interface,
# but only ever USE ONE for this. The other two ports can be used for other devices
# you want to connect. If you have more than one active WAN cable, you might experience
# layer 2 loops. (It's dead Jimmy!/No internet.)
uci add_list network.@device[0].ports='lan1'
uci add_list network.@device[0].ports='lan2'
uci add_list network.@device[0].ports='wan'

# Setting up my preferred VLAN IDs.
# 10 - (infra) Infrastructure
# 20 - (trusted) Trusted WiFi/LAN
# 30 - (guest) Guest Network
# 40 - (iot) Internet of Things devices and other such devices, like a frameo picture frame
for vlan_id in 10 20 30 40; do
  uci set "network.vlan${vlan_id}=bridge-vlan"
  uci set "network.vlan${vlan_id}.device=br-lan"
  uci set "network.vlan${vlan_id}.vlan=${vlan_id}"
  uci add_list "network.vlan${vlan_id}.ports=lan1:t"
  uci add_list "network.vlan${vlan_id}.ports=lan2:t"
  uci add_list "network.vlan${vlan_id}.ports=wan:t"
  uci add_list "network.vlan${vlan_id}.ports=phy1-mesh0:t"
done

uci set network.infra=interface
uci set network.infra.device='br-lan.10'
uci set network.infra.proto='dhcp'

uci set network.trusted=interface
uci set network.trusted.device='br-lan.20'
uci set network.trusted.proto='none'

uci set network.guest=interface
uci set network.guest.device='br-lan.30'
uci set network.guest.proto='none'

uci set network.iot=interface
uci set network.iot.device='br-lan.40'
uci set network.iot.proto='none'

# Multi VLAN tagging on backhaul between nodes.
uci set network.mesh_trunk=interface
uci set network.mesh_trunk.device='br-lan'
uci set network.mesh_trunk.proto='none'

uci commit network

# Remove DHCP, OPNsense on my Proxmox server handles this entirely.
uci delete dhcp.lan 2>/dev/null
uci commit dhcp 2>/dev/null
for svc in dnsmasq odhcpd firewall; do
  if [ -x "/etc/init.d/$svc" ]; then
    /etc/init.d/$svc disable >/dev/null 2>&1
    /etc/init.d/$svc stop >/dev/null 2>&1
  fi
done

# Add the provided SSH public key to dropbear if present, disable root password logins.
# If SSH_PUBLIC_KEY hasn't been provided, dropbear/SSH will still be disabled. But it won't be configured.
# (Would be able to password login with your WEB GUI login if enabled, and no SSH_PUBLIC_KEY is provided.)
if [ -f /etc/config/dropbear ]; then
  if [ -n "$SSH_PUBLIC_KEY" ]; then
    mkdir -p /etc/dropbear
    chmod 700 /etc/dropbear
    printf "%s\n" "$SSH_PUBLIC_KEY" >/etc/dropbear/authorized_keys
    chmod 600 /etc/dropbear/authorized_keys
    uci set dropbear.@dropbear[0].PasswordAuth='off'
    uci set dropbear.@dropbear[0].RootPasswordAuth='off'
  fi
  # Explicitly bind Dropbear SSH to the 'infra' (VLAN 10) interface. That way only
  # devices on VLAN 10 can even SSH into the WiFi node(s).
  uci set dropbear.@dropbear[0].Interface='infra'
  # Disable dropbear always, so you will have to activate it manually when needed
  # through the WEB GUI.
  uci set dropbear.@dropbear[0].enable='0'
  uci commit dropbear
  /etc/init.d/dropbear disable >/dev/null 2>&1
  /etc/init.d/dropbear stop >/dev/null 2>&1
fi

# ==============================================================================
# 4. Wireless Configuration (2.4 GHz HT20 + 5 GHz HE40 + 802.11s Mesh)
# ==============================================================================

# 2.4GHz specific changes, making sure it is set to the correct countrycode and
# is within EU rules
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.country="$COUNTRY_CODE"
uci set wireless.radio0.channel="$CH_2G"
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.cell_density='0'

# 5GHz specific changes, making sure it is set to the correct countrycode and
# is within EU rules and tuned for multi-node mesh overlap.
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.country="$COUNTRY_CODE"
uci set wireless.radio1.channel='36'
uci set wireless.radio1.htmode='HE40'
uci set wireless.radio1.txpower="$TX_5G"
uci set wireless.radio1.cell_density='0'

# SSID 1: My Trusted Mesh (Trusted Wi-Fi -> VLAN 20, 2.4 GHz + 5 GHz)
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='trusted'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid="$WIFI_TRUSTED_SSID"
uci set wireless.default_radio0.hidden='0'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key="$WIFI_TRUSTED_PASS"
uci set wireless.default_radio0.ieee80211w='0'

uci set wireless.default_radio1.device='radio1'
uci set wireless.default_radio1.network='trusted'
uci set wireless.default_radio1.mode='ap'
uci set wireless.default_radio1.ssid="$WIFI_TRUSTED_SSID"
uci set wireless.default_radio1.hidden='0'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key="$WIFI_TRUSTED_PASS"
uci set wireless.default_radio1.ieee80211w='0'
# Disable radio if password hasn't been changed from defaults.
if [ -z "$WIFI_TRUSTED_PASS" ] || [ "$WIFI_TRUSTED_PASS" = "CHANGE_ME" ]; then
  uci set wireless.default_radio0.disabled='1'
  uci set wireless.default_radio1.disabled='1'
else
  uci set wireless.default_radio0.disabled='0'
  uci set wireless.default_radio1.disabled='0'
fi

# This adds a specific MAC address to block from a node. If provided.
# I only really use this for blocking my Mac Mini M1 from connecting to WiFi
# on the upstairs node - since it gives me some specific trouble on this exact device.
if [ -n "$BLOCK_MAC" ]; then
  uci set wireless.default_radio0.macfilter='deny'
  uci add_list wireless.default_radio0.maclist="$BLOCK_MAC"
  uci set wireless.default_radio1.macfilter='deny'
  uci add_list wireless.default_radio1.maclist="$BLOCK_MAC"
fi

# SSID 2: My Guest WiFi (Guest Wi-Fi -> VLAN 30, 2.4 GHz + 5 GHz, Client Isolation)
uci set wireless.guest_2g=wifi-iface
uci set wireless.guest_2g.device='radio0'
uci set wireless.guest_2g.network='guest'
uci set wireless.guest_2g.mode='ap'
uci set wireless.guest_2g.ssid="$WIFI_GUEST_SSID"
uci set wireless.guest_2g.hidden='0'
uci set wireless.guest_2g.isolate='1'
uci set wireless.guest_2g.encryption='psk2'
uci set wireless.guest_2g.key="$WIFI_GUEST_PASS"
uci set wireless.guest_2g.ieee80211w='0'

uci set wireless.guest_5g=wifi-iface
uci set wireless.guest_5g.device='radio1'
uci set wireless.guest_5g.network='guest'
uci set wireless.guest_5g.mode='ap'
uci set wireless.guest_5g.ssid="$WIFI_GUEST_SSID"
uci set wireless.guest_5g.hidden='0'
uci set wireless.guest_5g.isolate='1'
uci set wireless.guest_5g.encryption='psk2'
uci set wireless.guest_5g.key="$WIFI_GUEST_PASS"
uci set wireless.guest_5g.ieee80211w='0'
# Disable radio if password hasn't been changed from defaults.
if [ -z "$WIFI_GUEST_PASS" ] || [ "$WIFI_GUEST_PASS" = "CHANGE_ME" ]; then
  uci set wireless.guest_2g.disabled='1'
  uci set wireless.guest_5g.disabled='1'
else
  uci set wireless.guest_2g.disabled='0'
  uci set wireless.guest_5g.disabled='0'
fi

# SSID 3: My IoT WiFi (IoT Wi-Fi -> VLAN 40, 2.4 GHz Only, Client Isolation)
uci set wireless.iot_2g=wifi-iface
uci set wireless.iot_2g.device='radio0'
uci set wireless.iot_2g.network='iot'
uci set wireless.iot_2g.mode='ap'
uci set wireless.iot_2g.ssid="$WIFI_IOT_SSID"
uci set wireless.iot_2g.hidden='0'
uci set wireless.iot_2g.isolate='1'
uci set wireless.iot_2g.encryption='psk2'
uci set wireless.iot_2g.key="$WIFI_IOT_PASS"
uci set wireless.iot_2g.ieee80211w='0'
# Disable radio if password hasn't been changed from defaults.
if [ -z "$WIFI_IOT_PASS" ] || [ "$WIFI_IOT_PASS" = "CHANGE_ME" ]; then
  uci set wireless.iot_2g.disabled='1'
else
  uci set wireless.iot_2g.disabled='0'
fi

# 802.11s Mesh Backhaul on 5 GHz (Carries all VLANs over mesh_trunk/br-lan)
uci set wireless.wifinet2=wifi-iface
uci set wireless.wifinet2.device='radio1'
uci set wireless.wifinet2.mode='mesh'
uci set wireless.wifinet2.network='mesh_trunk'
uci set wireless.wifinet2.encryption='sae'
uci set wireless.wifinet2.mesh_id="$MESH_BACKHAUL_ID"
uci set wireless.wifinet2.mesh_fwding='1'
uci set wireless.wifinet2.mesh_rssi_threshold='0'
uci set wireless.wifinet2.key="$MESH_BACKHAUL_PASS"
# Disable radio if password hasn't been changed from defaults.
if [ -z "$MESH_BACKHAUL_PASS" ] || [ "$MESH_BACKHAUL_PASS" = "CHANGE_ME" ]; then
  uci set wireless.wifinet2.disabled='1'
else
  uci set wireless.wifinet2.disabled='0'
fi

uci commit wireless

# ==============================================================================
# 5. Usteer Roaming Configuration
# ==============================================================================
if [ -f /etc/config/usteer ]; then
  uci set usteer.@usteer[0].network='trusted'
  uci set usteer.@usteer[0].syslog='1'
  uci set usteer.@usteer[0].local_mode='0'
  uci set usteer.@usteer[0].ipv6='0'
  uci set usteer.@usteer[0].debug_level='2'
  uci set usteer.@usteer[0].min_connect_snr="$MIN_CONNECT_SNR"
  uci set usteer.@usteer[0].min_snr='-85'
  uci set usteer.@usteer[0].roam_trigger_snr='-75'
  uci set usteer.@usteer[0].roam_scan_snr='-70'
  uci set usteer.@usteer[0].band_steering_interval='30000'
  uci set usteer.@usteer[0].band_steering_min_snr='-80'
  uci set usteer.@usteer[0].initial_connect_delay='500'
  uci set usteer.@usteer[0].assoc_steering='1'
  uci set usteer.@usteer[0].probe_steering='0'
  uci commit usteer
  /etc/init.d/usteer enable >/dev/null 2>&1
fi

# ==============================================================================
# 6. Attended Sysupgrade Defaults
# ==============================================================================
if [ -f /etc/config/attendedsysupgrade ]; then
  uci set attendedsysupgrade.client.upgrade_packages='1'
  uci set attendedsysupgrade.client.auto_search='0'
  uci set attendedsysupgrade.client.login_check_for_upgrades='0'
  uci commit attendedsysupgrade
fi

exit 0
