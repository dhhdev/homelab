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

# Safely inject all environment variables and update conditional checks in one pass
python3 - "${STAGING_DIR}/etc/uci-defaults/99-mesh-defaults" <<'EOF'
import sys, re, os

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

# Define variables to inject from environment
variables = [
    "MASTER_ROOT_PASS",
    "SSH_PUBLIC_KEY",
    "WIFI_TRUSTED_SSID",
    "WIFI_TRUSTED_PASS",
    "WIFI_GUEST_SSID",
    "WIFI_GUEST_PASS",
    "WIFI_IOT_SSID",
    "WIFI_IOT_PASS",
    "MESH_BACKHAUL_PASS"
]

for key in variables:
    val = os.environ.get(key, "")
    if val:
        # 1. Update variable assignments (e.g., KEY="CHANGE_ME" or KEY="")
        content = re.sub(rf'(?m)^\s*{key}="[^"]*"', f'{key}="{val}"', content)

        # 2. Update conditional checks comparing against "CHANGE_ME"
        content = content.replace(f'"${key}" = "CHANGE_ME"', f'"${key}" = "__CONFIGURED__"')
        content = content.replace(f"'{key}' = 'CHANGE_ME'", f"'{key}' = '__CONFIGURED__'")

with open(path, "w") as f:
    f.write(content)
EOF

chmod 755 "${STAGING_DIR}/etc/uci-defaults/99-mesh-defaults"

echo "Building OpenWrt ${OPENWRT_VERSION} for D-Link EAGLE PRO AI M32 A1..."
docker run --rm --platform linux/amd64 \
  -v "${STAGING_DIR}:/custom-files:ro" \
  -v "${OUT_DIR}:/output" \
  "openwrt/imagebuilder:mediatek-mt7622-${OPENWRT_VERSION}" \
  bash -c '
    make image \
      PROFILE="dlink_eagle-pro-ai-m32-a1" \
      PACKAGES="wpad-mesh-mbedtls luci luci-ssl luci-app-attendedsysupgrade usteer luci-app-usteer libubox netifd -dnsmasq -firewall4 -nftables -kmod-nft-offload -odhcp6c -odhcpd-ipv6only -ppp -ppp-mod-pppoe -wpad-basic-mbedtls" \
      FILES="/custom-files" && \
    cp bin/targets/mediatek/mt7622/*dlink_eagle-pro-ai-m32-a1*.bin /output/ && \
    cp build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_mt7622/root.squashfs /output/
  '

if [[ "${VERIFY_BUILD}" == 'true' ]]; then
  echo "Running verification script..."
  "${SCRIPT_DIR}/verify-firmware.sh"
else
  echo "Skipping build verification (VERIFY_BUILD=${VERIFY_BUILD})."
fi

echo "Done! Firmware images saved to: ${OUT_DIR}/"
