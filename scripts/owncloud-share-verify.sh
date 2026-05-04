#!/usr/bin/env bash
#
# Prueba end-to-end de compartir archivos entre usuarios autenticados con
# LDAP + OTP, validando que el destinatario puede leer el archivo cifrado.
#
# Flujo:
#   1. Enrola TOTP para emisor y destinatario en privacyIDEA.
#   2. Login web LDAP + OTP del emisor en OwnCloud.
#   3. Sube un archivo por WebDAV a la carpeta del emisor.
#   4. Crea share por OCS Sharing API hacia el destinatario.
#   5. Login web LDAP + OTP del destinatario.
#   6. Descarga el archivo por WebDAV desde el destinatario y valida contenido.
#   7. Confirma que el archivo en disco sigue cifrado (cabecera HBEGIN).
#
# Uso:
#   ./scripts/owncloud-share-verify.sh [emisor] [destinatario]
#
# Defaults: emisor=usuario.desarrollo1, destinatario=usuario.seguridad1

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
OC_CA_BUNDLE_PATH="${ROOT_DIR}/${OC_CA_BUNDLE:-certs/ca.crt}"
REALM_NAME="${PI_REALM_NAME:-sia}"
SENDER="${1:-usuario.desarrollo1}"
RECIPIENT="${2:-usuario.seguridad1}"

if [[ "${SENDER}" == "${RECIPIENT}" ]]; then
  echo "ERROR: emisor y destinatario no pueden ser el mismo usuario."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
SHARE_FILE="demo-compartido-${SENDER}.txt"
SHARE_CONTENT="sia-share-confidencial-$(date +%s)"
SENDER_SERIAL="TOTP_$(printf '%s' "${SENDER}" | tr -c '[:alnum:]-_' '_')"
RECIPIENT_SERIAL="TOTP_$(printf '%s' "${RECIPIENT}" | tr -c '[:alnum:]-_' '_')"

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

pi_admin_token() {
  local response
  response="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/auth" \
    --data-urlencode "username=${PI_ADMIN_USERNAME}" \
    --data-urlencode "password=${PI_ADMIN_PASSWORD}")"
  echo "${response}" | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["value"]["token"])
'
}

enroll_totp() {
  local user="$1"
  local serial="$2"
  local auth_header="$3"
  local response

  curl "${PI_CURL_OPTS[@]}" -fsS -X DELETE "${PI_URL}/token/${serial}" \
    -H "${auth_header}" >/dev/null 2>&1 || true

  response="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/token/init" \
    -H "${auth_header}" \
    --data-urlencode "type=totp" \
    --data-urlencode "user=${user}" \
    --data-urlencode "realm=${REALM_NAME}" \
    --data-urlencode "genkey=1" \
    --data-urlencode "otplen=6" \
    --data-urlencode "hashlib=sha1" \
    --data-urlencode "timeStep=30" \
    --data-urlencode "serial=${serial}")"

  echo "${response}" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("detail", {}).get("googleurl", {}).get("value", ""))
'
}

extract_totp_secret() {
  local otpauth_url="$1"
  printf '%s' "${otpauth_url}" | python3 -c '
import sys
from urllib.parse import parse_qs, urlparse

url = sys.stdin.read().strip()
print(parse_qs(urlparse(url).query).get("secret", [""])[0])
'
}

# Ejecuta login completo LDAP + OTP en OwnCloud para `user`. Llena el
# archivo de cookies en `cookies_file`. Imprime el `requesttoken` actual.
oc_login_full() {
  local user="$1"
  local password="$2"
  local secret="$3"
  local cookies_file="$4"
  local stage_file
  stage_file="${TMP_DIR}/$(basename "${cookies_file}")-stage.html"

  rm -f "${cookies_file}"
  curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -c "${cookies_file}" \
    "${OC_URL}/login" > "${stage_file}"
  local login_token
  login_token="$(extract_request_token "${stage_file}")"

  local post_login
  post_login="${TMP_DIR}/$(basename "${cookies_file}")-post-login.txt"
  curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
    -b "${cookies_file}" -c "${cookies_file}" \
    -X POST "${OC_URL}/login" \
    --data-urlencode "user=${user}" \
    --data-urlencode "password=${password}" \
    --data-urlencode "requesttoken=${login_token}" \
    --data-urlencode "timezone=America/Mexico_City" \
    --data-urlencode "timezone-offset=0" > "${post_login}"

  if ! grep -qi '^location: /login/selectchallenge' "${post_login}"; then
    echo "ERROR: OwnCloud no redirigió al selector 2FA para ${user}." >&2
    sed -n '1,40p' "${post_login}" >&2
    return 1
  fi

  local remaining
  remaining=$((30 - ($(date +%s) % 30)))
  if (( remaining < 8 )); then
    sleep $((remaining + 1))
  fi
  local current_otp
  current_otp="$(totp_from_secret "${secret}")"

  curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -L \
    -b "${cookies_file}" -c "${cookies_file}" \
    "${OC_URL}/login/selectchallenge" > "${stage_file}"
  local challenge_token
  challenge_token="$(extract_request_token "${stage_file}")"

  local post_otp
  post_otp="${TMP_DIR}/$(basename "${cookies_file}")-post-otp.txt"
  curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
    -b "${cookies_file}" -c "${cookies_file}" \
    -X POST "${OC_URL}/login/challenge/privacyidea" \
    --data-urlencode "challenge=${current_otp}" \
    --data-urlencode "mode=otp" \
    --data-urlencode "modeChanged=0" \
    --data-urlencode "requesttoken=${challenge_token}" > "${post_otp}"

  if ! grep -qi '^location: .*/apps/files/' "${post_otp}"; then
    echo "ERROR: OwnCloud no aceptó el OTP de ${user}." >&2
    sed -n '1,80p' "${post_otp}" >&2
    return 1
  fi

  curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -L \
    -b "${cookies_file}" -c "${cookies_file}" \
    "${OC_URL}/apps/files/" > "${stage_file}"
  extract_request_token "${stage_file}"
}

remove_existing_share() {
  local cookies_file="$1"
  local request_token="$2"
  local file_path="$3"

  local list_xml
  list_xml="$(curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
    -b "${cookies_file}" -c "${cookies_file}" \
    -H "OCS-APIRequest: true" \
    -H "requesttoken: ${request_token}" \
    "${OC_URL}/ocs/v1.php/apps/files_sharing/api/v1/shares?path=${file_path}" 2>/dev/null || true)"

  local ids
  ids="$(printf '%s' "${list_xml}" | python3 -c '
import re, sys
text = sys.stdin.read()
for sid in re.findall(r"<id>(\d+)</id>", text):
    print(sid)
')"

  while IFS= read -r sid; do
    [[ -z "${sid}" ]] && continue
    curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
      -b "${cookies_file}" -c "${cookies_file}" \
      -H "OCS-APIRequest: true" \
      -H "requesttoken: ${request_token}" \
      -X DELETE "${OC_URL}/ocs/v1.php/apps/files_sharing/api/v1/shares/${sid}" >/dev/null 2>&1 || true
  done <<< "${ids}"
}

echo "==> 1. Creando tokens TOTP para emisor (${SENDER}) y destinatario (${RECIPIENT})"
ADMIN_TOKEN="$(pi_admin_token)"
AUTH_HEADER="Authorization: ${ADMIN_TOKEN}"

SENDER_OTPAUTH="$(enroll_totp "${SENDER}" "${SENDER_SERIAL}" "${AUTH_HEADER}")"
RECIPIENT_OTPAUTH="$(enroll_totp "${RECIPIENT}" "${RECIPIENT_SERIAL}" "${AUTH_HEADER}")"
SENDER_SECRET="$(extract_totp_secret "${SENDER_OTPAUTH}")"
RECIPIENT_SECRET="$(extract_totp_secret "${RECIPIENT_OTPAUTH}")"

if [[ -z "${SENDER_SECRET}" || -z "${RECIPIENT_SECRET}" ]]; then
  echo "ERROR: no se pudo extraer alguno de los secretos TOTP."
  exit 1
fi
echo "OK"

echo
echo "==> 2. Login de ${SENDER} (LDAP + OTP)"
SENDER_COOKIES="${TMP_DIR}/sender-cookies"
SENDER_RT="$(oc_login_full "${SENDER}" "${LDAP_USER_PASSWORD}" "${SENDER_SECRET}" "${SENDER_COOKIES}")"
echo "OK"

echo
echo "==> 3. Subiendo archivo de demostración como ${SENDER}"
printf '%s\n' "${SHARE_CONTENT}" > "${TMP_DIR}/${SHARE_FILE}"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${SENDER_COOKIES}" -c "${SENDER_COOKIES}" \
  -X PUT "${OC_URL}/remote.php/webdav/${SHARE_FILE}" \
  --data-binary "@${TMP_DIR}/${SHARE_FILE}" > "${TMP_DIR}/put-share.txt"

if ! grep -Eq '^HTTP/[0-9.]+ (201|204)' "${TMP_DIR}/put-share.txt"; then
  echo "ERROR: OwnCloud no aceptó la subida WebDAV del emisor."
  sed -n '1,40p' "${TMP_DIR}/put-share.txt"
  exit 1
fi
echo "OK"

echo
echo "==> 4. Creando share de ${SHARE_FILE} hacia ${RECIPIENT} via OCS API"
remove_existing_share "${SENDER_COOKIES}" "${SENDER_RT}" "/${SHARE_FILE}"

SHARE_RESPONSE="$(curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
  -b "${SENDER_COOKIES}" -c "${SENDER_COOKIES}" \
  -H "OCS-APIRequest: true" \
  -H "requesttoken: ${SENDER_RT}" \
  -X POST "${OC_URL}/ocs/v1.php/apps/files_sharing/api/v1/shares" \
  --data-urlencode "path=/${SHARE_FILE}" \
  --data-urlencode "shareType=0" \
  --data-urlencode "shareWith=${RECIPIENT}" \
  --data-urlencode "permissions=19")"

SHARE_STATUS="$(printf '%s' "${SHARE_RESPONSE}" | python3 -c '
import re, sys
text = sys.stdin.read()
m = re.search(r"<statuscode>(\d+)</statuscode>", text)
print(m.group(1) if m else "")
')"

if [[ "${SHARE_STATUS}" != "100" && "${SHARE_STATUS}" != "200" ]]; then
  echo "ERROR: OCS API rechazó el share. statuscode=${SHARE_STATUS}"
  echo "${SHARE_RESPONSE}"
  exit 1
fi
echo "OK"

echo
echo "==> 5. Verificando que el archivo en disco sigue cifrado"
DATA_FILE="/mnt/data/files/${SENDER}/files/${SHARE_FILE}"
if docker exec otpsec-owncloud-server sh -lc "grep -aF '${SHARE_CONTENT}' '${DATA_FILE}' >/dev/null"; then
  echo "ERROR: el archivo quedó en texto plano dentro del volumen."
  exit 1
fi
if ! docker exec otpsec-owncloud-server sh -lc "head -c 80 '${DATA_FILE}' | grep -aF 'HBEGIN:oc_encryption_module' >/dev/null"; then
  echo "ERROR: el archivo no tiene cabecera de cifrado de OwnCloud."
  exit 1
fi
echo "OK"

echo
echo "==> 6. Login de ${RECIPIENT} (LDAP + OTP)"
RECIPIENT_COOKIES="${TMP_DIR}/recipient-cookies"
oc_login_full "${RECIPIENT}" "${LDAP_USER_PASSWORD}" "${RECIPIENT_SECRET}" "${RECIPIENT_COOKIES}" >/dev/null
echo "OK"

echo
echo "==> 7. ${RECIPIENT} descarga el archivo compartido y valida contenido en claro"
DOWNLOAD_FILE="${TMP_DIR}/${SHARE_FILE}.recv"
curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
  -b "${RECIPIENT_COOKIES}" -c "${RECIPIENT_COOKIES}" \
  -o "${DOWNLOAD_FILE}" \
  "${OC_URL}/remote.php/webdav/${SHARE_FILE}"

if ! grep -qF "${SHARE_CONTENT}" "${DOWNLOAD_FILE}"; then
  echo "ERROR: el contenido descargado por ${RECIPIENT} no coincide."
  echo "Contenido recibido:"
  sed -n '1,5p' "${DOWNLOAD_FILE}"
  exit 1
fi
echo "OK: ${RECIPIENT} descifró y leyó el archivo compartido."

echo
echo "Resumen:"
echo "  - Archivo subido: /${SHARE_FILE}"
echo "  - Compartido con: ${RECIPIENT} (permisos 19 = leer + actualizar + compartir)"
echo "  - En disco: cifrado con OwnCloud server-side encryption"
echo "  - Lectura por destinatario: OK"
