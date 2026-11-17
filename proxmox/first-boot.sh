#!/usr/bin/env bash
set -euo pipefail

# 1. Configure VLAN-aware vmbr0 trunk + vmbr0.10 management & disable NIC offloading
PRIMARY_NIC=$(ip -o -4 route show to default | awk '{print $5}')

if [[ -z "${PRIMARY_NIC}" ]]; then
  echo "ERROR: Could not detect primary NIC." >&2
  exit 1
fi

cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback

iface ${PRIMARY_NIC} inet manual
    post-up /sbin/ethtool -K ${PRIMARY_NIC} tso off gso off gro off tx off rx off

auto vmbr0
iface vmbr0 inet manual
    bridge-ports ${PRIMARY_NIC}
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094

auto vmbr0.10
iface vmbr0.10 inet static
    address 10.0.10.2/24
    gateway 10.0.10.1

source /etc/network/interfaces.d/*
EOF

# Apply host network settings immediately so the bridge is stable
ifreload -a

# 2. Locate ISO payload
PAYLOAD_DIR=""
for candidate in \
  "/run/live/medium/homelab-payload" \
  "/run/proxmox-installer/homelab-payload" \
  "/media/cdrom/homelab-payload"; do
  if [[ -d "${candidate}" ]]; then
    PAYLOAD_DIR="${candidate}"
    break
  fi
done

# 3. Create VM 101 (OPNsense — Gateway 10.0.10.1) & attach seed config disk
qm create 101 \
  --name opnsense \
  --ostype other \
  --cpu host \
  --sockets 1 \
  --cores 2 \
  --memory 2048 \
  --balloon 0 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:40,discard=on,iothread=1,ssd=1 \
  --net0 virtio=BC:24:11:43:00:84,bridge=vmbr0,queues=2 \
  --net1 virtio=BC:24:11:6E:92:04,bridge=vmbr0,queues=2,tag=101 \
  --agent enabled=1 \
  --boot "order=scsi0;net0" \
  --tags internal \
  --onboot 1 \
  --startup "order=1,up=30"

if [[ -n "${PAYLOAD_DIR}" && -f "${PAYLOAD_DIR}/101-opnsense/config.xml" ]]; then
  SEED_IMG="/var/lib/vz/images/101/opnsense-seed.img"
  mkdir -p /var/lib/vz/images/101
  dd if=/dev/zero of="${SEED_IMG}" bs=1M count=8 status=none
  mkfs.vfat -n OPNsense "${SEED_IMG}" >/dev/null
  MNT_TMP="$(mktemp -d)"
  mount -o loop "${SEED_IMG}" "${MNT_TMP}"
  mkdir -p "${MNT_TMP}/conf"
  cp "${PAYLOAD_DIR}/101-opnsense/config.xml" "${MNT_TMP}/conf/config.xml"
  umount "${MNT_TMP}"
  rmdir "${MNT_TMP}"
  qm set 101 --ide0 "local:101/opnsense-seed.img"
fi

# Boot OPNsense & wait for WAN connectivity before downloading LXC templates
qm start 101 || true
echo "Waiting for OPNsense WAN connectivity..."
for _ in $(seq 1 45); do
  if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    echo "WAN is up."
    break
  fi
  sleep 3
done

# 4. Download Debian 12 template & create LXC 199 (Caddy Reverse Proxy on VLAN 10)
pveam update
DEBIAN_TMPL=$(pveam available -section system | awk '/debian-12-standard/ {print $2}' | tail -n1)
pveam download local "${DEBIAN_TMPL}"

pct create 199 "local:vztmpl/${DEBIAN_TMPL}" \
  --hostname proxy \
  --arch amd64 \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,tag=10,firewall=1,gw=10.0.10.1,hwaddr=BC:24:11:BD:85:75,ip=10.0.10.99/24 \
  --features nesting=1 \
  --unprivileged 1 \
  --tags internal \
  --onboot 1 \
  --startup "order=2,up=30"

pct start 199

# 5. Provision Caddy inside LXC 199
if [[ -n "${PAYLOAD_DIR}" && -d "${PAYLOAD_DIR}/199-caddy-proxy" ]]; then
  sleep 5
  pct push 199 "${PAYLOAD_DIR}/199-caddy-proxy" /opt/199-caddy-proxy -r
  pct exec 199 -- mkdir -p /opt/199-caddy-proxy/certs
  pct push 199 /etc/pve/pve-root-ca.pem /opt/199-caddy-proxy/certs/pve-root-ca.pem
  pct exec 199 -- bash /opt/199-caddy-proxy/provision-lxc.sh
fi
