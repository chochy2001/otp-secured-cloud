#!/usr/bin/env bash
#
# Verifica que OwnCloud esté corriendo y responda por HTTPS contra la
# CA local del proyecto. En esta fase aún no validamos LDAP backend ni
# 2FA: eso lo cubre el siguiente script de la fase. Aquí solo se prueba
# que el servicio web responde y que el admin puede usar OCC.
#
# Salida con exit 0 si todo OK, exit != 0 si algo falla.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

OC_URL="${OC_URL:-https://localhost:9443}"
OC_ADMIN_USERNAME="${OC_ADMIN_USERNAME:-admin}"
CA_BUNDLE="${ROOT_DIR}/${PI_CA_BUNDLE:-certs/ca.crt}"
SERVER_CONTAINER="otpsec-owncloud-server"
PROXY_CONTAINER="otpsec-owncloud-proxy"

if ! docker ps --format '{{.Names}}' | grep -q "^${SERVER_CONTAINER}$"; then
  echo "ERROR: el contenedor ${SERVER_CONTAINER} no está corriendo."
  echo "Arráncalo con:  cd compose && docker compose up -d"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER}$"; then
  echo "ERROR: el contenedor ${PROXY_CONTAINER} no está corriendo."
  exit 1
fi

CURL_OPTS=()
if [[ "${OC_URL}" == https://* ]] && [[ -f "${CA_BUNDLE}" ]]; then
  CURL_OPTS+=(--cacert "${CA_BUNDLE}")
fi

echo "==> 1. Caddy expone HTTPS en ${OC_URL} con cert firmado por la CA"
TLS_OUT="$(echo | openssl s_client -connect "$(echo "${OC_URL}" | sed 's#https://##' | sed 's#/$##')" \
  -CAfile "${CA_BUNDLE}" -servername owncloud 2>/dev/null)"
if ! echo "${TLS_OUT}" | grep -q "Verify return code: 0 (ok)"; then
  echo "ERROR: el cert presentado por OwnCloud no validó contra ${CA_BUNDLE}."
  exit 1
fi
SUBJECT="$(echo "${TLS_OUT}" | grep -m1 '^subject=' | sed 's/^subject=//')"
echo "OK: ${SUBJECT}"

echo
echo "==> 2. Endpoint público /status.php reporta instalación correcta"
STATUS_RESP="$(curl "${CURL_OPTS[@]}" -fsS "${OC_URL}/status.php")"
INSTALLED="$(echo "${STATUS_RESP}" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data.get("installed", False))
')"
VERSION="$(echo "${STATUS_RESP}" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("versionstring", ""))
')"
if [[ "${INSTALLED}" != "True" ]]; then
  echo "ERROR: OwnCloud reporta installed=${INSTALLED}."
  exit 1
fi
echo "OK: instalación detectada, versión ${VERSION}"

echo
echo "==> 3. OCC dentro del contenedor responde como www-data"
if ! docker exec --user www-data "${SERVER_CONTAINER}" occ status >/dev/null 2>&1; then
  echo "ERROR: occ status falló dentro del contenedor."
  exit 1
fi
echo "OK"

echo
echo "==> 4. El admin '${OC_ADMIN_USERNAME}' existe en la base de OwnCloud"
USER_LIST="$(docker exec --user www-data "${SERVER_CONTAINER}" occ user:list --output=json 2>/dev/null || true)"
if ! echo "${USER_LIST}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
users = data if isinstance(data, list) else list(data.keys())
sys.exit(0 if '${OC_ADMIN_USERNAME}' in users else 1)
" 2>/dev/null; then
  echo "ERROR: el admin '${OC_ADMIN_USERNAME}' no aparece en occ user:list."
  exit 1
fi
echo "OK"

echo
echo "Todo OK."
