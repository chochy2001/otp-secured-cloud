#!/usr/bin/env bash
#
# Prueba end-to-end del login web de OwnCloud:
# LDAP como primer factor y privacyIDEA TOTP como segundo factor.
#
# Uso:
#   ./scripts/owncloud-login-verify.sh [usuario]
#
# Default seguro: usuario.desarrollo2. El usuario.desarrollo1 se reserva
# para la demo manual con el token físico del teléfono.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/.env" ]]; then
  echo "ERROR: no existe ${ROOT_DIR}/.env"
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/.env"

PI_URL="${PI_URL:-https://localhost:8443}"
OC_URL="${OC_URL:-https://localhost:9443}"
OC_CA_BUNDLE="${OC_CA_BUNDLE:-certs/ca.crt}"
REALM_NAME="${PI_REALM_NAME:-sia}"
TEST_USER="${1:-usuario.desarrollo2}"
TEST_SERIAL="TOTP_$(printf '%s' "${TEST_USER}" | tr -c '[:alnum:]-_' '_')"
TMP_DIR="$(mktemp -d)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib-curl.sh"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

extract_request_token() {
  local html_file="$1"
  python3 - "$html_file" <<'PYEOF'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
patterns = [
    r'name="requesttoken" value="([^"]+)"',
    r'data-requesttoken="([^"]+)"',
]
for pattern in patterns:
    match = re.search(pattern, text)
    if match:
        print(match.group(1))
        raise SystemExit(0)
raise SystemExit(1)
PYEOF
}

totp_from_secret() {
  local secret="$1"
  SECRET="${secret}" python3 - <<'PYEOF'
import base64
import hashlib
import hmac
import os
import struct
import time

key = base64.b32decode(os.environ["SECRET"], casefold=True)
counter = int(time.time()) // 30
msg = struct.pack(">Q", counter)
digest = hmac.new(key, msg, hashlib.sha1).digest()
offset = digest[-1] & 0x0F
code = (struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF) % 1000000
print(f"{code:06d}")
PYEOF
}

echo "==> 1. Creando token TOTP de prueba para ${TEST_USER}@${REALM_NAME}"
AUTH_RESPONSE="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/auth" \
  --data-urlencode "username=${PI_ADMIN_USERNAME}" \
  --data-urlencode "password=${PI_ADMIN_PASSWORD}")"

ADMIN_TOKEN="$(echo "${AUTH_RESPONSE}" | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["value"]["token"])
')"
AUTH_HEADER="Authorization: ${ADMIN_TOKEN}"

curl "${PI_CURL_OPTS[@]}" -fsS -X DELETE "${PI_URL}/token/${TEST_SERIAL}" -H "${AUTH_HEADER}" >/dev/null 2>&1 || true

INIT_RESPONSE="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/token/init" \
  -H "${AUTH_HEADER}" \
  --data-urlencode "type=totp" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "genkey=1" \
  --data-urlencode "otplen=6" \
  --data-urlencode "hashlib=sha1" \
  --data-urlencode "timeStep=30" \
  --data-urlencode "serial=${TEST_SERIAL}")"

OTPAUTH_URL="$(echo "${INIT_RESPONSE}" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("detail", {}).get("googleurl", {}).get("value", ""))
')"

TOTP_SECRET="$(echo "${OTPAUTH_URL}" | python3 -c '
import sys
from urllib.parse import parse_qs, urlparse

url = sys.stdin.read().strip()
print(parse_qs(urlparse(url).query).get("secret", [""])[0])
')"

if [[ -z "${TOTP_SECRET}" ]]; then
  echo "ERROR: no se pudo extraer el secreto TOTP."
  exit 1
fi
echo "OK"

REMAINING=$((30 - ($(date +%s) % 30)))
if (( REMAINING < 8 )); then
  sleep $((REMAINING + 1))
fi
CURRENT_OTP="$(totp_from_secret "${TOTP_SECRET}")"

echo
echo "==> 2. Login de primer factor contra OwnCloud"
curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" -c "${TMP_DIR}/cookies" \
  "${OC_URL}/login" > "${TMP_DIR}/login.html"
LOGIN_TOKEN="$(extract_request_token "${TMP_DIR}/login.html")"

curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" -i \
  -b "${TMP_DIR}/cookies" -c "${TMP_DIR}/cookies" \
  -X POST "${OC_URL}/login" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "password=${LDAP_USER_PASSWORD}" \
  --data-urlencode "requesttoken=${LOGIN_TOKEN}" \
  --data-urlencode "timezone=America/Mexico_City" \
  --data-urlencode "timezone-offset=0" > "${TMP_DIR}/post-login.txt"

if ! grep -qi '^location: /login/selectchallenge' "${TMP_DIR}/post-login.txt"; then
  echo "ERROR: OwnCloud no redirigió al selector 2FA."
  sed -n '1,40p' "${TMP_DIR}/post-login.txt"
  exit 1
fi
echo "OK"

echo
echo "==> 3. Enviando OTP al plugin twofactor_privacyidea"
curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" -L \
  -b "${TMP_DIR}/cookies" -c "${TMP_DIR}/cookies" \
  "${OC_URL}/login/selectchallenge" > "${TMP_DIR}/challenge.html"
CHALLENGE_TOKEN="$(extract_request_token "${TMP_DIR}/challenge.html")"

curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" -i \
  -b "${TMP_DIR}/cookies" -c "${TMP_DIR}/cookies" \
  -X POST "${OC_URL}/login/challenge/privacyidea" \
  --data-urlencode "challenge=${CURRENT_OTP}" \
  --data-urlencode "mode=otp" \
  --data-urlencode "modeChanged=0" \
  --data-urlencode "requesttoken=${CHALLENGE_TOKEN}" > "${TMP_DIR}/post-otp.txt"

if ! grep -qi '^location: .*\/apps\/files\/' "${TMP_DIR}/post-otp.txt"; then
  echo "ERROR: OwnCloud no aceptó el OTP o no abrió la sesión."
  sed -n '1,80p' "${TMP_DIR}/post-otp.txt"
  exit 1
fi

echo "OK: OwnCloud aceptó LDAP + OTP y abrió la sesión de archivos."

echo
echo "==> 4. Subiendo archivo y validando cifrado en disco"
DEMO_FILE="demo-cifrado.txt"
DEMO_CONTENT="sia-demo-confidencial-$(date +%s)"
printf '%s\n' "${DEMO_CONTENT}" > "${TMP_DIR}/${DEMO_FILE}"

curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" -i \
  -b "${TMP_DIR}/cookies" -c "${TMP_DIR}/cookies" \
  -X PUT "${OC_URL}/remote.php/webdav/${DEMO_FILE}" \
  --data-binary "@${TMP_DIR}/${DEMO_FILE}" > "${TMP_DIR}/put-file.txt"

if ! grep -Eq '^HTTP/[0-9.]+ (201|204)' "${TMP_DIR}/put-file.txt"; then
  echo "ERROR: OwnCloud no aceptó la subida WebDAV."
  sed -n '1,80p' "${TMP_DIR}/put-file.txt"
  exit 1
fi

DATA_FILE="/mnt/data/files/${TEST_USER}/files/${DEMO_FILE}"
if docker exec otpsec-owncloud-server sh -lc "grep -aF '${DEMO_CONTENT}' '${DATA_FILE}' >/dev/null"; then
  echo "ERROR: el archivo quedó en texto plano dentro del volumen."
  exit 1
fi

if ! docker exec otpsec-owncloud-server sh -lc "head -c 80 '${DATA_FILE}' | grep -aF 'HBEGIN:oc_encryption_module' >/dev/null"; then
  echo "ERROR: el archivo no tiene cabecera de cifrado de OwnCloud."
  exit 1
fi

echo "OK: archivo subido y cifrado en el volumen."
echo
echo "URL para app TOTP si se quiere usar el mismo token en demo manual:"
echo "  ${OTPAUTH_URL}"
