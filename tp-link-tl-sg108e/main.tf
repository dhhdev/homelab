terraform {
  required_version = ">= 1.6.0"
  required_providers {
    tplinkeasysmart = {
      source  = "davidlukac/tplinkeasysmart"
      version = "~> 0.1"
    }
  }
}

provider "tplinkeasysmart" {
  host     = var.switch_ip
  mac      = "60:15:6f:6e:92:7a"
  username = var.switch_user
  password = var.switch_password
}

# --- 802.1Q VLAN Mode & Groups ---
resource "tplinkeasysmart_vlan_mode" "this" {
  mode = "802.1q"
}

# VLAN 101: ISP Carrier WAN Trunk (ONT Port 1 <-> Proxmox Port 2)
resource "tplinkeasysmart_vlan_8021q_group" "isp_wan" {
  vlan           = 101
  name           = "ISP"
  tagged_ports   = [1, 2]
  untagged_ports = []
}

# VLAN 10: Infra Management (Tagged on Trunks 2 & 3; Untagged on Port 8 Rescue)
resource "tplinkeasysmart_vlan_8021q_group" "infra" {
  vlan           = 10
  name           = "infra"
  tagged_ports   = [2, 3]
  untagged_ports = [8]
}

# VLAN 20: Trusted Devices (Tagged on Trunks 2 & 3; Untagged on Access Ports 4-7)
resource "tplinkeasysmart_vlan_8021q_group" "trusted" {
  vlan           = 20
  name           = "trusted"
  tagged_ports   = [2, 3]
  untagged_ports = [4, 5, 6, 7]
}

# VLAN 30: Guest Wi-Fi (Tagged on Trunks 2 & 3)
resource "tplinkeasysmart_vlan_8021q_group" "guest" {
  vlan           = 30
  name           = "guest"
  tagged_ports   = [2, 3]
  untagged_ports = []
}

# VLAN 40: IoT / Smart Home (Tagged on Trunks 2 & 3)
resource "tplinkeasysmart_vlan_8021q_group" "iot" {
  vlan           = 40
  name           = "iot"
  tagged_ports   = [2, 3]
  untagged_ports = []
}

# --- Port PVIDs (Native VLANs) ---
resource "tplinkeasysmart_vlan_8021q_pvid" "port_1_ont" {
  port = 1
  pvid = 101
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_2_proxmox" {
  port = 2
  pvid = 10
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_3_wifi_main" {
  port = 3
  pvid = 10
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_4" {
  port = 4
  pvid = 20
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_5" {
  port = 5
  pvid = 20
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_6" {
  port = 6
  pvid = 20
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_7" {
  port = 7
  pvid = 20
}

# Port 8: Dedicated Infra / Emergency Rescue ("Oh Shit") Access Port
resource "tplinkeasysmart_vlan_8021q_pvid" "port_8_rescue" {
  port = 8
  pvid = 10
}
