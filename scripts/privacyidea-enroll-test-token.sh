#!/usr/bin/env bash
#
# Enrola un token TOTP de prueba en PrivacyIDEA y valida que funciona
# de punta a punta, SIN necesidad de un teléfono.
#
# Flujo:
#   1. Se autentica como admin via /auth.
#   2. Borra cualquier token previo con el mismo serial (idempotente).
#   3. Crea un TOTP nuevo con /token/init y genkey=1 (PrivacyIDEA genera
#      la semilla, no hay valor hardcodeado en el repo).
#   4. Imprime la URL otpauth:// para que pueda escanearse con FreeOTP.
#   5. Calcula el TOTP actual localmente usando solo Python stdlib
#      (hmac + hashlib + struct), sin oathtool ni pyotp.
#   6. Valida ese código contra POST /validate/check.
#
# El mismo endpoint /validate/check es el que usará OwnCloud en la
# Fase 5 cuando el plugin twofactor_privacyidea invoque PrivacyIDEA.
#
# Uso:
#   ./scripts/privacyidea-enroll-test-token.sh [usuario]
#
# Si no se pasa usuario, se usa usuario.desarrollo1.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib-curl.sh"

PI_URL="${PI_URL:-https://localhost:8443}"
REALM_NAME="${PI_REALM_NAME:-sia}"
TEST_USER="${1:-usuario.desarrollo1}"
# PrivacyIDEA exige serial con regex ^[0-9a-zA-Z\-_]+$ (sin puntos).
# Se reemplazan caracteres no permitidos del username por guion bajo.
TEST_SERIAL="TOTP_$(printf '%s' "${TEST_USER}" | tr -c '[:alnum:]-_' '_')"

echo "==> 1. Autenticando admin contra ${PI_URL}"
TOKEN_RESP="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/auth" \
  --data-urlencode "username=${PI_ADMIN_USERNAME}" \
  --data-urlencode "password=${PI_ADMIN_PASSWORD}")"

ADMIN_TOKEN="$(echo "$TOKEN_RESP" | python3 -c '
import json, sys
print(json.load(sys.stdin)["result"]["value"]["token"])
')"

if [[ -z "$ADMIN_TOKEN" ]]; then
  echo "ERROR: no se obtuvo token de admin"
  exit 1
fi
echo "OK"

AUTH_HEADER="Authorization: ${ADMIN_TOKEN}"

echo
echo "==> 2. Borrando token previo con serial '${TEST_SERIAL}' (si existe)"
if curl "${PI_CURL_OPTS[@]}" -fsS -X DELETE "${PI_URL}/token/${TEST_SERIAL}" -H "${AUTH_HEADER}" >/dev/null 2>&1; then
  echo "Token previo eliminado."
else
  echo "No había token previo, sigo adelante."
fi

echo
echo "==> 3. Enrolando TOTP nuevo con genkey=1 para '${TEST_USER}@${REALM_NAME}'"
INIT_RESP="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/token/init" \
  -H "${AUTH_HEADER}" \
  --data-urlencode "type=totp" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "genkey=1" \
  --data-urlencode "otplen=6" \
  --data-urlencode "hashlib=sha1" \
  --data-urlencode "timeStep=30" \
  --data-urlencode "serial=${TEST_SERIAL}")"

# El campo detail.otpkey.value viene en formato "seed://<hex>".
# detail.googleurl.value trae la URL otpauth:// que se escanea con FreeOTP.
OTPKEY_HEX="$(echo "$INIT_RESP" | python3 -c '
import json, sys
data = json.load(sys.stdin)
val = data.get("detail", {}).get("otpkey", {}).get("value", "")
if val.startswith("seed://"):
    print(val[len("seed://"):])
')"

OTPAUTH_URL="$(echo "$INIT_RESP" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data.get("detail", {}).get("googleurl", {}).get("value", ""))
')"

if [[ -z "$OTPKEY_HEX" ]]; then
  echo "ERROR: no se obtuvo la semilla del token en la respuesta de /token/init"
  echo "Respuesta cruda: $INIT_RESP"
  exit 1
fi

echo "OK: token '${TEST_SERIAL}' creado."
echo
echo "URL para escanear con FreeOTP (demo manual):"
echo "  ${OTPAUTH_URL}"

echo
echo "==> 4. Calculando TOTP actual localmente (hmac-sha1, ventana 30s)"
CURRENT_OTP="$(OTPKEY_HEX="$OTPKEY_HEX" python3 - <<'PYEOF'
import hmac, hashlib, struct, time, binascii, os

key = binascii.unhexlify(os.environ["OTPKEY_HEX"])
counter = int(time.time()) // 30
msg = struct.pack(">Q", counter)
digest = hmac.new(key, msg, hashlib.sha1).digest()
offset = digest[-1] & 0x0F
code = (struct.unpack(">I", digest[offset:offset+4])[0] & 0x7FFFFFFF) % 1000000
print("{:06d}".format(code))
PYEOF
)"

echo "OTP calculado: ${CURRENT_OTP}"

echo
echo "==> 5. Validando el OTP contra POST /validate/check (mismo endpoint que OwnCloud)"
VALIDATE_RESP="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/validate/check" \
  --data-urlencode "user=${TEST_USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "pass=${CURRENT_OTP}")"

ACCEPTED="$(echo "$VALIDATE_RESP" | python3 -c '
import json, sys
print(json.load(sys.stdin).get("result", {}).get("value", False))
')"

if [[ "$ACCEPTED" != "True" ]]; then
  echo "ERROR: PrivacyIDEA rechazó el OTP calculado."
  echo "Respuesta completa:"
  echo "$VALIDATE_RESP" | python3 -m json.tool
  exit 1
fi

echo "OK: PrivacyIDEA aceptó el OTP generado localmente."

echo
echo "Fase 3 del proyecto cerrada de punta a punta:"
echo "  Identificación + primer factor (LDAP)"
echo "  + segundo factor (PrivacyIDEA TOTP validado)"
echo
echo "Para la demo con el teléfono, escanea la URL de arriba con FreeOTP:"
echo "  ${OTPAUTH_URL}"
