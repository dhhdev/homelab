#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
CADDY_BIN="${SCRIPT_DIR}/caddy-linux-amd64"

if [[ ! -f "${CADDY_BIN}" ]]; then
  echo "Error: ${CADDY_BIN} not found. Run ./build-caddy.sh first." >&2
  exit 1
fi

# 1. Install minimal runtime dependencies & create caddy system user
apt-get update
apt-get install -y --no-install-recommends ca-certificates

if ! id -u caddy >/dev/null 2>&1; then
  groupadd --system caddy
  useradd --system \
    --gid caddy \
    --create-home \
    --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin \
    --comment "Caddy web server" \
    caddy
fi

mkdir -p /etc/caddy/root_site /etc/systemd/system/caddy.service.d

# 2. Install xcaddy-compiled binary
install -m 755 "${CADDY_BIN}" /usr/bin/caddy

# 3. Install systemd unit & environment override
cp "${SCRIPT_DIR}/caddy.service" /etc/systemd/system/caddy.service
cp "${SCRIPT_DIR}/caddy.service.d/override.conf" /etc/systemd/system/caddy.service.d/override.conf

# 4. Deploy Caddyfile, root_site, and secrets (if present)
cp "${SCRIPT_DIR}/Caddyfile" /etc/caddy/Caddyfile
if [[ -d "${SCRIPT_DIR}/root_site" ]]; then
  cp -r "${SCRIPT_DIR}/root_site/." /etc/caddy/root_site/
fi

if [[ -f "${SCRIPT_DIR}/caddy.env" ]]; then
  cp "${SCRIPT_DIR}/caddy.env" /etc/caddy/caddy.env
  chown root:caddy /etc/caddy/caddy.env
  chmod 640 /etc/caddy/caddy.env
fi

chown -R root:caddy /etc/caddy
chmod 755 /etc/caddy /etc/caddy/root_site

# 5. Validate config & start service
systemctl daemon-reload
systemctl enable caddy
if [[ -f /etc/caddy/caddy.env ]]; then
  caddy validate --config /etc/caddy/Caddyfile --envfile /etc/caddy/caddy.env
  systemctl restart caddy
else
  echo "Warning: /etc/caddy/caddy.env not found. Populate it and run 'systemctl restart caddy'."
fi
