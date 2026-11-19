#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

shopt -s nullglob
bin_files=("${BUILD_DIR}"/*.bin)
shopt -u nullglob

if [[ ${#bin_files[@]} -eq 0 ]]; then
  echo "Error: No .bin files found in ${BUILD_DIR}. Run build-firmware.sh first." >&2
  exit 1
fi

# Prefer a sysupgrade image if multiple .bin files exist
TARGET_BIN=""
for candidate in "${bin_files[@]}"; do
  if [[ "$(basename "${candidate}")" == *sysupgrade* ]]; then
    TARGET_BIN="${candidate}"
    break
  fi
done
if [[ -z "${TARGET_BIN}" ]]; then
  TARGET_BIN="${bin_files[0]}"
fi

BIN_NAME="$(basename "${TARGET_BIN}")"
echo "Verifying ${BIN_NAME} from ${BUILD_DIR}..."

docker run --rm --platform linux/amd64 \
  -v "${BUILD_DIR}:/build_dir:ro" \
  debian:bookworm \
  bash -c '
    set -euo pipefail
    BIN_NAME="$1"
    IMG_PATH="/build_dir/${BIN_NAME}"

    apt-get update -qq && apt-get install -y -qq squashfs-tools python3 >/dev/null
    mkdir -p /tmp/work && cd /tmp/work

    # OpenWrt firmware .bin images contain a SquashFS magic header ("hsqs" little-endian or "sqsh" big-endian)
    OFFSET=$(python3 -c '\''
import sys
data = open(sys.argv[1], "rb").read()
for magic in (b"hsqs", b"sqsh"):
    idx = data.find(magic)
    if idx != -1:
        print(idx)
        sys.exit(0)
sys.exit(1)
'\'' "${IMG_PATH}") || {
      echo "FAIL: Could not locate an embedded SquashFS image inside ${BIN_NAME}." >&2
      exit 1
    }

    echo "Found embedded SquashFS at byte offset ${OFFSET}."
    unsquashfs -offset "${OFFSET}" -d rootfs "${IMG_PATH}" >/dev/null

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
    echo "PASS: Permissions (755), POSIX syntax, and secret injection verified in ${BIN_NAME}."
    grep -E "^WIFI_.*_SSID=" "${TARGET}" || true
    for key in MASTER_ROOT_PASS WIFI_TRUSTED_PASS WIFI_GUEST_PASS WIFI_IOT_PASS MESH_BACKHAUL_PASS; do
      val=$(grep -E "^${key}=" "${TARGET}" | head -n1 | cut -d"=" -f2- | tr -d "\"")
      if [[ -n "${val}" ]]; then
        echo "${key}=[SET (${#val} chars)]"
      else
        echo "${key}=[EMPTY]"
      fi
    done
  ' _ "${BIN_NAME}"
