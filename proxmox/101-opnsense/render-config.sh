#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
TEMPLATE_FILE="${SCRIPT_DIR}/config.xml.template"
OUTPUT_FILE="${SCRIPT_DIR}/config.xml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Error: ${ENV_FILE} not found. Copy .env.example to .env and populate secrets first." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

VARS='${OPNSENSE_DALLE_PASSWORD_HASH} ${PPPOE_USERNAME} ${PPPOE_PASSWORD} ${OPNSENSE_WEBGUI_CERT_B64} ${OPNSENSE_WEBGUI_KEY_B64}'

envsubst "${VARS}" < "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"
chmod 600 "${OUTPUT_FILE}"

echo "Rendered ${OUTPUT_FILE} successfully (permissions set to 600)."
