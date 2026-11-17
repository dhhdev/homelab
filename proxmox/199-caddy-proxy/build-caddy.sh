#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
OUTPUT_BIN="${SCRIPT_DIR}/caddy-linux-amd64"

if ! command -v xcaddy >/dev/null 2>&1; then
  echo "Installing xcaddy..."
  go install ://github.com
  export PATH="$(go env GOPATH)/bin:${PATH}"
fi

echo "Building latest Caddy with for linux/amd64..."
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 xcaddy build \
  --with github.com/caddy-dns/cloudflare \
  --output "${OUTPUT_BIN}"

chmod 755 "${OUTPUT_BIN}"
echo "Built ${OUTPUT_BIN} successfully."
