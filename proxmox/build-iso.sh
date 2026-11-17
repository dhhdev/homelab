#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
PVE_ISO="${1:-proxmox-ve_9.2-1.iso}"
OUT_ISO="${SCRIPT_DIR}/proxmox-ve-homelab-unattended.iso"
STAGING_DIR="$(mktemp -d)"

trap 'rm -rf "${STAGING_DIR}"' EXIT

if [[ ! -f "${PVE_ISO}" ]]; then
  echo "Usage: $0 <path-to-official-proxmox-ve.iso>" >&2
  exit 1
fi

# 1. Build xcaddy binary if not already built
if [[ ! -f "${SCRIPT_DIR}/199-caddy-proxy/caddy-linux-amd64" ]]; then
  bash "${SCRIPT_DIR}/199-caddy-proxy/build-caddy.sh"
fi

# 2. Render OPNsense config.xml if .env is present
if [[ -f "${SCRIPT_DIR}/101-opnsense/.env" ]]; then
  bash "${SCRIPT_DIR}/101-opnsense/render-config.sh"
fi

# 3. Prepare ISO payload
mkdir -p "${STAGING_DIR}/homelab-payload"
cp -r "${SCRIPT_DIR}/199-caddy-proxy" "${STAGING_DIR}/homelab-payload/"
if [[ -f "${SCRIPT_DIR}/101-opnsense/config.xml" ]]; then
  mkdir -p "${STAGING_DIR}/homelab-payload/101-opnsense"
  cp "${SCRIPT_DIR}/101-opnsense/config.xml" "${STAGING_DIR}/homelab-payload/101-opnsense/"
fi

# 4. Bake answer.toml, first-boot.sh, and payload into Proxmox ISO
proxmox-auto-install-assistant prepare-iso "${PVE_ISO}" \
  --fetch-from iso \
  --answer-file "${SCRIPT_DIR}/answer.toml" \
  --on-first-boot "${SCRIPT_DIR}/first-boot.sh" \
  --extra-files "${STAGING_DIR}/homelab-payload" \
  --output "${OUT_ISO}"

echo "Unattended ISO created: ${OUT_ISO}"
