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

# --- Adopt Existing Live Switch State (Zero-Disruption Import) ---

import {
  to = tplinkeasysmart_vlan_mode.this
  id = "vlan_mode"
}

import {
  to = tplinkeasysmart_vlan_8021q_group.default_lan
  id = "1"
}

import {
  to = tplinkeasysmart_vlan_8021q_group.isp_wan
  id = "101"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_1_ont
  id = "1"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_2_proxmox
  id = "2"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_3_wifi_main
  id = "3"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_4
  id = "4"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_5
  id = "5"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_6
  id = "6"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_7
  id = "7"
}

import {
  to = tplinkeasysmart_vlan_8021q_pvid.port_8_rescue
  id = "8"
}

# --- 802.1Q VLAN Mode & Groups ---

resource "tplinkeasysmart_vlan_mode" "this" {
  mode = "802.1q"
}

# VLAN 1: Default Flat LAN (Ports 2-8 Untagged, Port 1 Isolated)
resource "tplinkeasysmart_vlan_8021q_group" "default_lan" {
  vlan           = 1
  name           = "Default"
  tagged_ports   = []
  untagged_ports = [2, 3, 4, 5, 6, 7, 8]
}

# VLAN 101: ISP Carrier WAN Trunk (ONT Port 1 <-> Proxmox/OPNsense Port 2)
resource "tplinkeasysmart_vlan_8021q_group" "isp_wan" {
  vlan           = 101
  name           = "ISP"
  tagged_ports   = [1, 2]
  untagged_ports = []
}

# --- Port PVIDs (Native VLANs) ---

resource "tplinkeasysmart_vlan_8021q_pvid" "port_1_ont" {
  port = 1
  pvid = 101
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_2_proxmox" {
  port = 2
  pvid = 1
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_3_wifi_main" {
  port = 3
  pvid = 1
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_4" {
  port = 4
  pvid = 1
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_5" {
  port = 5
  pvid = 1
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_6" {
  port = 6
  pvid = 1
}

resource "tplinkeasysmart_vlan_8021q_pvid" "port_7" {
  port = 7
  pvid = 1
}

# Port 8: Dedicated Infra / Emergency Rescue ("Oh Shit") Access Port
resource "tplinkeasysmart_vlan_8021q_pvid" "port_8_rescue" {
  port = 8
  pvid = 1
}
