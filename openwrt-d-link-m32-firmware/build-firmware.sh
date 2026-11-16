#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
OUT_DIR="${SCRIPT_DIR}/bin"
STAGING_DIR="$(mktemp -d)"

trap 'rm -rf "${STAGING_DIR}"' EXIT

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: ${ENV_FILE} not found. Copy .env.example to .env and populate secrets first." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

OPENWRT_VERSION="${OPENWRT_VERSION:-24.10.0}"
VERIFY_BUILD="${VERIFY_BUILD:-true}"

mkdir -p "${STAGING_DIR}/etc/uci-defaults" "${OUT_DIR}"
cp "${SCRIPT_DIR}/uci-mesh-defaults.sh" "${STAGING_DIR}/etc/uci-defaults/99-mesh-defaults"

# Safely inject SSIDs, passwords, and SSH key into the staged uci-defaults script
VARS=(
  MASTER_ROOT_PASS
  SSH_PUBLIC_KEY
  WIFI_TRUSTED_SSID
  WIFI_TRUSTED_PASS
  WIFI_GUEST_SSID
  WIFI_GUEST_PASS
  WIFI_IOT_SSID
  WIFI_IOT_PASS
  MESH_BACKHAUL_PASS
)

for var in "${VARS[@]}"; do
  if [[ -n "${!var:-}" ]]; then
    python3 - "${STAGING_DIR}/etc/uci-defaults/99-mesh-defaults" "${var}" << 'EOF'
import os, sys
path, key = sys.argv, sys.argv
val = os.environ[key]
with open(path, "r") as f:
    lines = f.readlines()
with open(path, "w") as f:
    for line in lines:
        if line.startswith(f"{key}="):
            f.write(f'{key}="{val}"\n')
        else:
            f.write(line)
EOF
  fi
done

chmod 755 "${STAGING_DIR}/etc/uci-defaults/99-mesh-defaults"

echo "Building OpenWrt ${OPENWRT_VERSION} for D-Link EAGLE PRO AI M32 A1..."
docker run --rm --platform linux/amd64 \
  -v "${STAGING_DIR}:/custom-files:ro" \
  -v "${OUT_DIR}:/output" \
  "openwrt/imagebuilder:mediatek-mt7622-${OPENWRT_VERSION}" \
  bash -c '
    make image \
      PROFILE="dlink_eagle-pro-ai-m32-a1" \
      PACKAGES="wpad-mesh-mbedtls luci luci-ssl luci-app-attendedsysupgrade usteer luci-app-usteer -dnsmasq -firewall4 -nftables -kmod-nft-offload -odhcp6c -odhcpd-ipv6only -ppp -ppp-mod-pppoe -wpad-basic-mbedtls" \
      FILES="/custom-files" && \
    cp bin/targets/mediatek/mt7622/*dlink_eagle-pro-ai-m32-a1*.bin /output/
  '

if [[ "${VERIFY_BUILD}" == "true" ]]; then
  "${SCRIPT_DIR}/verify-firmware.sh"
else
  echo "Skipping build verification (VERIFY_BUILD=${VERIFY_BUILD})."
fi

echo "Done! Firmware images saved to: ${OUT_DIR}/"
