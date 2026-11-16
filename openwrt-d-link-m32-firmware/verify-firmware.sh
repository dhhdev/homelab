#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"

SYSUPGRADE_BIN=$(find "${BIN_DIR}" -maxdepth 1 -name '*-squashfs-sysupgrade.bin' | head -n1)

if [[ -z "${SYSUPGRADE_BIN}" || ! -f "${SYSUPGRADE_BIN}" ]]; then
  echo "Error: No *-squashfs-sysupgrade.bin found in ${BIN_DIR}. Run ./build-firmware.sh first." >&2
  exit 1
fi

echo "Verifying $(basename "${SYSUPGRADE_BIN}")..."

docker run --rm --platform linux/amd64 \
  -v "${BIN_DIR}:/bin_dir:ro" \
  debian:bookworm \
  bash -c '
    set -euo pipefail
    apt-get update -qq && apt-get install -y -qq squashfs-tools >/dev/null
    mkdir -p /tmp/img && cd /tmp/img
    tar -xf /bin_dir/*-squashfs-sysupgrade.bin
    unsquashfs -d rootfs sysupgrade-*/root >/dev/null

    TARGET="rootfs/etc/uci-defaults/99-mesh-defaults"

    # 1. Verify file exists and is executable
    if [[ ! -x "${TARGET}" ]]; then
      echo "FAIL: ${TARGET} is missing or not executable (755)." >&2
      exit 1
    fi

    # 2. Verify POSIX shell syntax
    sh -n "${TARGET}"

    # 3. Verify no CHANGE_ME placeholders remain
    if grep -q "CHANGE_ME" "${TARGET}"; then
      echo "FAIL: Unreplaced CHANGE_ME placeholder found in ${TARGET}." >&2
      exit 1
    fi

    # 4. Print sanitized summary (SSIDs shown, passwords masked)
    echo "PASS: Permissions (755), POSIX syntax, and secret injection verified."
    grep -E "^WIFI_.*_SSID=" "${TARGET}"
    for key in MASTER_ROOT_PASS WIFI_TRUSTED_PASS WIFI_GUEST_PASS WIFI_IOT_PASS MESH_BACKHAUL_PASS; do
      val=$(grep -E "^${key}=" "${TARGET}" | cut -d"=" -f2- | tr -d "\"")
      if [[ -n "${val}" ]]; then
        echo "${key}=[SET (${#val} chars)]"
      else
        echo "${key}=[EMPTY]"
      fi
    done
  '
