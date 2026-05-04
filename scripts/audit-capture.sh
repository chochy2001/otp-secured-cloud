#!/usr/bin/env bash
#
# Captura de bitácoras de auditoría para los componentes del proyecto.
#
# Dispara eventos representativos del control de acceso y guarda los
# extractos relevantes de los logs de OpenLDAP, PrivacyIDEA y OwnCloud
# en docs/auditoria.md, en formato listo para incluir en la memoria
# técnica.
#
# Eventos cubiertos:
#   1. Login LDAP exitoso (bind con password correcto)
#   2. Login LDAP fallido (bind con password incorrecto)
#   3. Enrolamiento de token TOTP en privacyIDEA
#   4. OTP correcto validado contra privacyIDEA
#   5. OTP incorrecto rechazado por privacyIDEA
#   6. Login web OwnCloud LDAP + OTP exitoso
#   7. Login web OwnCloud con OTP rechazado
#   8. Acceso a archivo por WebDAV (subida y descarga)
#
# Uso:
#   ./scripts/audit-capture.sh [usuario]
#
# Default: usuario.desarrollo2 (para no chocar con otros scripts).

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
TEST_USER="${1:-usuario.desarrollo2}"
TEST_SERIAL="TOTP_AUDIT_$(printf '%s' "${TEST_USER}" | tr -c '[:alnum:]-_' '_')"
OUTPUT_FILE="${ROOT_DIR}/docs/auditoria.md"
TMP_DIR="$(mktemp -d)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib-curl.sh"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

# Espera 1 segundo para que los logs se escriban antes de capturar.
let_logs_settle() {
  sleep 1
}

iso_now() {
  date -u +%Y-%m-%dT%H:%M:%S
}

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

# Captura las líneas relevantes de un componente desde un timestamp dado.
# Filtros suaves: simplemente saca las últimas N líneas. Para mayor
# precisión se incluye un grep posterior por usuario o palabra clave.
capture_ldap_for_user() {
  local user="$1"
  local lines="${2:-50}"
  # Tomar las últimas líneas del slapd log que mencionen al usuario en
  # el BIND, junto con el RESULT del mismo conn= que sigue inmediatamente.
  docker logs --tail "${lines}" otpsec-openldap 2>&1 | \
    awk -v u="uid=${user}," '
      /BIND dn=/ && $0 ~ u { conn=$2; print; capture=1; next }
      capture && /RESULT/ && $2 == conn { print; capture=0 }
      capture && /BIND/ && $2 == conn { print }
    ' | tail -10 || true
}

capture_privacyidea_for_user() {
  local user="$1"
  local pattern="${2:-}"
  local lines="${3:-300}"
  # Combinar el log interno (eventos de framework) con docker logs
  # (uwsgi access log con HTTP/200/401) para que sean útiles.
  {
    docker exec otpsec-privacyidea sh -lc \
      "tail -n ${lines} /var/log/privacyidea/privacyidea.log 2>/dev/null"
    docker logs --tail "${lines}" otpsec-privacyidea 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g'
  } | grep -E "(${user}|${pattern})" | tail -12 || true
}

capture_owncloud_since() {
  local user="$1"
  local marker="$2"
  local pattern="${3:-}"
  local filter_script
  filter_script='import json
import os
import re
import sys

user = os.environ.get("USER_ARG", "")
mark = os.environ.get("MARK_ARG", "")
pattern = os.environ.get("PATTERN_ARG", "")
needle = re.compile(pattern, re.IGNORECASE) if pattern else None

kept = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        entry = json.loads(line)
    except json.JSONDecodeError:
        continue
    when = entry.get("time", "")
    if mark and when < mark:
        continue
    payload = json.dumps(entry, ensure_ascii=False)
    if user and user not in payload and "twofactor" not in payload.lower():
        if not (needle and needle.search(payload)):
            continue
    if needle and not needle.search(payload):
        continue
    kept.append(payload)

for line in kept[-8:]:
    print(line)
'
  docker exec otpsec-owncloud-server sh -lc 'cat /mnt/data/files/owncloud.log 2>/dev/null' | \
    USER_ARG="${user}" MARK_ARG="${marker}" PATTERN_ARG="${pattern}" \
      python3 -c "${filter_script}" || true
}

write_section() {
  local title="$1"
  local description="$2"
  local marker="$3"
  shift 3

  {
    echo
    echo "## ${title}"
    echo
    echo "${description}"
    echo
    echo "Marcador (UTC): \`${marker}\`"
    while (($#)); do
      local component="$1"
      local content="$2"
      shift 2
      echo
      echo "### ${component}"
      echo
      if [[ -z "${content// }" ]]; then
        echo "(sin entradas relevantes)"
      else
        echo '```'
        printf '%s\n' "${content}"
        echo '```'
      fi
    done
  } >> "${OUTPUT_FILE}"
}

mkdir -p "$(dirname "${OUTPUT_FILE}")"
{
  echo "# Auditoría: muestreo de eventos de control de acceso"
  echo
  echo "Generado por \`scripts/audit-capture.sh\` el $(iso_now) UTC."
  echo
  echo "Este documento contiene extractos de logs reales de los tres"
  echo "componentes del proyecto, capturados al disparar eventos clave"
  echo "del flujo de autenticación. Sirve como evidencia de la cuarta"
  echo "capa del control de acceso (auditoría) y para que el equipo y"
  echo "el evaluador entiendan dónde mirar en cada componente."
  echo
  echo "Componente | Fuente del log"
  echo "---|---"
  echo "OpenLDAP | \`docker logs otpsec-openldap\` (slapd a stdout/stderr)"
  echo "PrivacyIDEA | \`docker logs otpsec-privacyidea\` y \`/var/log/privacyidea/\` dentro del contenedor"
  echo "OwnCloud | \`/mnt/data/files/owncloud.log\` dentro del contenedor (JSON estructurado)"
  echo
  echo "Las secciones siguientes muestran la salida directa, sin reescribir."
} > "${OUTPUT_FILE}"

echo "==> Generando bitácora en ${OUTPUT_FILE}"
echo "    Usuario de pruebas: ${TEST_USER}"

# Subir loglevel de OwnCloud a debug (0) durante la captura para que
# registre eventos del plugin twofactor_privacyidea, WebDAV y cifrado.
# Al final del script se restaura a info (1) que es el valor sano para
# laboratorio.
docker exec --user www-data otpsec-owncloud-server occ \
  config:system:set loglevel --value=0 --type=integer >/dev/null

restore_owncloud_loglevel() {
  docker exec --user www-data otpsec-owncloud-server occ \
    config:system:set loglevel --value=1 --type=integer >/dev/null 2>&1 || true
}
trap 'cleanup; restore_owncloud_loglevel' EXIT

# ----------------------------------------------------------------------
# 1. Login LDAP exitoso
# ----------------------------------------------------------------------
echo
echo "==> 1. Login LDAP exitoso"
MARK="$(iso_now)"
docker exec otpsec-openldap ldapwhoami -x -H ldap://localhost \
  -D "uid=${TEST_USER},ou=Desarrollo,ou=Usuarios,${LDAP_BASE_DN}" \
  -w "${LDAP_USER_PASSWORD}" >/dev/null
let_logs_settle
LDAP_OK_LOG="$(capture_ldap_for_user "${TEST_USER}" 30)"
write_section \
  "1. Login LDAP exitoso" \
  "Bind directo del usuario \`${TEST_USER}\` con su contraseña LDAP. Cierra el primer factor de autenticación. Esperado en el log: BIND con \`err=0\`." \
  "${MARK}" \
  "OpenLDAP" "${LDAP_OK_LOG}"

# ----------------------------------------------------------------------
# 2. Login LDAP fallido
# ----------------------------------------------------------------------
echo "==> 2. Login LDAP fallido"
MARK="$(iso_now)"
docker exec otpsec-openldap ldapwhoami -x -H ldap://localhost \
  -D "uid=${TEST_USER},ou=Desarrollo,ou=Usuarios,${LDAP_BASE_DN}" \
  -w "password-incorrecto" >/dev/null 2>&1 || true
let_logs_settle
LDAP_FAIL_LOG="$(capture_ldap_for_user "${TEST_USER}" 30)"
write_section \
  "2. Login LDAP fallido" \
  "Bind del mismo usuario con contraseña incorrecta. Esperado en el log: BIND con \`err=49\` (invalidCredentials)." \
  "${MARK}" \
  "OpenLDAP" "${LDAP_FAIL_LOG}"

# ----------------------------------------------------------------------
# 3. Token TOTP enrolado
# ----------------------------------------------------------------------
echo "==> 3. Enrolamiento de token TOTP"
MARK="$(iso_now)"
ADMIN_TOKEN="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/auth" \
  --data-urlencode "username=${PI_ADMIN_USERNAME}" \
  --data-urlencode "password=${PI_ADMIN_PASSWORD}" | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["value"]["token"])
')"
AUTH_HEADER="Authorization: ${ADMIN_TOKEN}"

curl "${PI_CURL_OPTS[@]}" -fsS -X DELETE "${PI_URL}/token/${TEST_SERIAL}" \
  -H "${AUTH_HEADER}" >/dev/null 2>&1 || true

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
TOTP_SECRET="$(printf '%s' "${OTPAUTH_URL}" | python3 -c '
import sys
from urllib.parse import parse_qs, urlparse
print(parse_qs(urlparse(sys.stdin.read().strip()).query).get("secret", [""])[0])
')"

let_logs_settle
PI_ENROLL_LOG="$(capture_privacyidea_for_user "${TEST_USER}" "token.init|TOTP" 200)"
write_section \
  "3. Enrolamiento de token TOTP" \
  "El admin de privacyIDEA crea un token TOTP para \`${TEST_USER}\` con \`genkey=1\`. Esperado: una línea POST \`/token/init\` y respuesta 200 en el log de uwsgi/Flask." \
  "${MARK}" \
  "PrivacyIDEA" "${PI_ENROLL_LOG}"

# ----------------------------------------------------------------------
# 4. OTP correcto validado
# ----------------------------------------------------------------------
echo "==> 4. OTP correcto validado"
# Forzar siguiente ventana TOTP para que el OTP usado aquí no choque
# con el que se usará en la sección 6.
sleep $((30 - ($(date +%s) % 30) + 1))
GOOD_OTP="$(totp_from_secret "${TOTP_SECRET}")"

MARK="$(iso_now)"
curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/validate/check" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "pass=${GOOD_OTP}" >/dev/null
let_logs_settle
PI_OK_LOG="$(capture_privacyidea_for_user "${TEST_USER}" "validate|check_serial_pass|matching_token" 200)"
write_section \
  "4. OTP correcto validado" \
  "El cliente (en producción sería OwnCloud) valida un OTP vigente contra \`POST /validate/check\`. Esperado: respuesta con \`result.status=True\` y \`result.value=True\`." \
  "${MARK}" \
  "PrivacyIDEA" "${PI_OK_LOG}"

# ----------------------------------------------------------------------
# 5. OTP incorrecto rechazado
# ----------------------------------------------------------------------
echo "==> 5. OTP incorrecto rechazado"
MARK="$(iso_now)"
curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/validate/check" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "pass=000000" >/dev/null
let_logs_settle
PI_FAIL_LOG="$(capture_privacyidea_for_user "${TEST_USER}" "validate|check_serial_pass|wrong otp|mismatch|fail" 200)"
write_section \
  "5. OTP incorrecto rechazado" \
  "Mismo endpoint con OTP \`000000\`. Esperado: \`result.value=False\`." \
  "${MARK}" \
  "PrivacyIDEA" "${PI_FAIL_LOG}"

# ----------------------------------------------------------------------
# 6 y 7 y 8: flujo OwnCloud (login OK + login OTP fail + WebDAV)
# ----------------------------------------------------------------------
echo "==> 6. Login web OwnCloud LDAP + OTP exitoso"
COOKIES="${TMP_DIR}/cookies"
rm -f "${COOKIES}"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -c "${COOKIES}" "${OC_URL}/login" \
  > "${TMP_DIR}/login.html"
LOGIN_TOKEN="$(extract_request_token "${TMP_DIR}/login.html")"

MARK_OK="$(iso_now)"
curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${COOKIES}" -c "${COOKIES}" \
  -X POST "${OC_URL}/login" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "password=${LDAP_USER_PASSWORD}" \
  --data-urlencode "requesttoken=${LOGIN_TOKEN}" \
  --data-urlencode "timezone=America/Mexico_City" \
  --data-urlencode "timezone-offset=0" > "${TMP_DIR}/post-login.txt"

# Forzar nueva ventana TOTP para evitar replay del OTP usado en sección 4.
sleep $((30 - ($(date +%s) % 30) + 1))
CURRENT_OTP="$(totp_from_secret "${TOTP_SECRET}")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -L \
  -b "${COOKIES}" -c "${COOKIES}" \
  "${OC_URL}/login/selectchallenge" > "${TMP_DIR}/challenge.html"
CHALLENGE_TOKEN="$(extract_request_token "${TMP_DIR}/challenge.html")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${COOKIES}" -c "${COOKIES}" \
  -X POST "${OC_URL}/login/challenge/privacyidea" \
  --data-urlencode "challenge=${CURRENT_OTP}" \
  --data-urlencode "mode=otp" \
  --data-urlencode "modeChanged=0" \
  --data-urlencode "requesttoken=${CHALLENGE_TOKEN}" > "${TMP_DIR}/post-otp.txt"

if ! grep -qi '^location: .*/apps/files/' "${TMP_DIR}/post-otp.txt"; then
  echo "AVISO: la sección 6 no registró redirección a /apps/files. Revisar logs." >&2
fi

let_logs_settle
OC_OK_LOG="$(capture_owncloud_since "${TEST_USER}" "${MARK_OK}" "login|challenge|privacyidea")"
write_section \
  "6. Login web OwnCloud LDAP + OTP exitoso" \
  "Flujo web completo: primer factor LDAP, redirección a selector 2FA, validación de OTP en el plugin \`twofactor_privacyidea\` y apertura de la vista de archivos." \
  "${MARK_OK}" \
  "OwnCloud" "${OC_OK_LOG}"

# ----------------------------------------------------------------------
# 7. Login web OwnCloud con OTP rechazado
# ----------------------------------------------------------------------
echo "==> 7. Login web OwnCloud con OTP rechazado"
COOKIES_FAIL="${TMP_DIR}/cookies-fail"
rm -f "${COOKIES_FAIL}"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -c "${COOKIES_FAIL}" \
  "${OC_URL}/login" > "${TMP_DIR}/login-fail.html"
LOGIN_TOKEN_FAIL="$(extract_request_token "${TMP_DIR}/login-fail.html")"

MARK_FAIL="$(iso_now)"
curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${COOKIES_FAIL}" -c "${COOKIES_FAIL}" \
  -X POST "${OC_URL}/login" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "password=${LDAP_USER_PASSWORD}" \
  --data-urlencode "requesttoken=${LOGIN_TOKEN_FAIL}" \
  --data-urlencode "timezone=America/Mexico_City" \
  --data-urlencode "timezone-offset=0" > "${TMP_DIR}/post-login-fail.txt"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -L \
  -b "${COOKIES_FAIL}" -c "${COOKIES_FAIL}" \
  "${OC_URL}/login/selectchallenge" > "${TMP_DIR}/challenge-fail.html"
CHALLENGE_TOKEN_FAIL="$(extract_request_token "${TMP_DIR}/challenge-fail.html")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${COOKIES_FAIL}" -c "${COOKIES_FAIL}" \
  -X POST "${OC_URL}/login/challenge/privacyidea" \
  --data-urlencode "challenge=000000" \
  --data-urlencode "mode=otp" \
  --data-urlencode "modeChanged=0" \
  --data-urlencode "requesttoken=${CHALLENGE_TOKEN_FAIL}" > "${TMP_DIR}/post-otp-fail.txt"

let_logs_settle
OC_FAIL_LOG="$(capture_owncloud_since "${TEST_USER}" "${MARK_FAIL}" "login|challenge|privacyidea|fail|reject")"
write_section \
  "7. Login web OwnCloud con OTP rechazado" \
  "Mismo flujo que el caso 6 pero el OTP enviado al plugin es \`000000\`. Esperado: el plugin \`twofactor_privacyidea\` redirige al selector de challenge y la sesión NO se eleva a la vista de archivos." \
  "${MARK_FAIL}" \
  "OwnCloud" "${OC_FAIL_LOG}"

# ----------------------------------------------------------------------
# 8. Acceso a archivo por WebDAV (PUT y GET)
# ----------------------------------------------------------------------
echo "==> 8. Acceso a archivo por WebDAV (PUT y GET)"
DEMO_FILE="audit-demo.txt"
DEMO_CONTENT="audit-${RANDOM}"
printf '%s\n' "${DEMO_CONTENT}" > "${TMP_DIR}/${DEMO_FILE}"

# Login limpio para WebDAV: el paso 7 puede invalidar la sesión del 6.
COOKIES8="${TMP_DIR}/cookies-step8"
rm -f "${COOKIES8}"
curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -c "${COOKIES8}" \
  "${OC_URL}/login" > "${TMP_DIR}/login8.html"
LOGIN_TOKEN8="$(extract_request_token "${TMP_DIR}/login8.html")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -i \
  -b "${COOKIES8}" -c "${COOKIES8}" \
  -X POST "${OC_URL}/login" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "password=${LDAP_USER_PASSWORD}" \
  --data-urlencode "requesttoken=${LOGIN_TOKEN8}" \
  --data-urlencode "timezone=America/Mexico_City" \
  --data-urlencode "timezone-offset=0" >/dev/null

# Forzar siguiente ventana TOTP para evitar replay del OTP usado en
# la sección 6 (privacyIDEA bloquea reutilización dentro de la misma ventana).
sleep $((30 - ($(date +%s) % 30) + 1))
CURRENT_OTP8="$(totp_from_secret "${TOTP_SECRET}")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" -L \
  -b "${COOKIES8}" -c "${COOKIES8}" \
  "${OC_URL}/login/selectchallenge" > "${TMP_DIR}/challenge8.html"
CHALLENGE_TOKEN8="$(extract_request_token "${TMP_DIR}/challenge8.html")"

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
  -b "${COOKIES8}" -c "${COOKIES8}" \
  -X POST "${OC_URL}/login/challenge/privacyidea" \
  --data-urlencode "challenge=${CURRENT_OTP8}" \
  --data-urlencode "mode=otp" \
  --data-urlencode "modeChanged=0" \
  --data-urlencode "requesttoken=${CHALLENGE_TOKEN8}" >/dev/null

MARK_PUT="$(iso_now)"
curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
  -b "${COOKIES8}" -c "${COOKIES8}" \
  -X PUT "${OC_URL}/remote.php/webdav/${DEMO_FILE}" \
  --data-binary "@${TMP_DIR}/${DEMO_FILE}" >/dev/null

curl -fsS --cacert "${OC_CA_BUNDLE_PATH}" \
  -b "${COOKIES8}" -c "${COOKIES8}" \
  -o "${TMP_DIR}/${DEMO_FILE}.recv" \
  "${OC_URL}/remote.php/webdav/${DEMO_FILE}"

let_logs_settle
OC_FILE_LOG="$(capture_owncloud_since "${TEST_USER}" "${MARK_PUT}" "webdav|${DEMO_FILE}|files_encryption|PUT|GET")"
write_section \
  "8. Acceso a archivo por WebDAV" \
  "Subida (PUT) y descarga (GET) de \`${DEMO_FILE}\` por el usuario autenticado. Esperado: dos peticiones WebDAV registradas con código 2xx; el cifrado del lado servidor es transparente." \
  "${MARK_PUT}" \
  "OwnCloud" "${OC_FILE_LOG}"

echo
echo "Auditoría escrita en ${OUTPUT_FILE}."
echo "Revísala con: less ${OUTPUT_FILE}"
