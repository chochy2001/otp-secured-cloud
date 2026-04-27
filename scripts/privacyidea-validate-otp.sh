#!/usr/bin/env bash
#
# Valida un código OTP contra PrivacyIDEA para un usuario del realm sia.
#
# Uso:
#   ./scripts/privacyidea-validate-otp.sh <usuario> <otp>
#
# Ejemplo:
#   ./scripts/privacyidea-validate-otp.sh usuario.desarrollo1 287543
#
# El script invoca el endpoint público /validate/check (no requiere
# autenticación de admin, ése es el mismo endpoint que usa OwnCloud
# cuando el plugin twofactor_privacyidea valida el segundo factor).
#
# Termina con exit 0 si PrivacyIDEA acepta el código, exit 1 si lo
# rechaza, exit 2 si hay error de red o parseo.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 2 ]]; then
  echo "Uso: $0 <usuario> <otp>"
  echo "Ejemplo: $0 usuario.desarrollo1 287543"
  exit 2
fi

USER="$1"
OTP="$2"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env"
  exit 2
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

PI_URL="${PI_URL:-https://localhost:8443}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib-curl.sh"

REALM_NAME="${PI_REALM_NAME:-sia}"

echo "==> Validando OTP para '${USER}@${REALM_NAME}' contra ${PI_URL}"

RESPONSE="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/validate/check" \
  --data-urlencode "user=${USER}" \
  --data-urlencode "realm=${REALM_NAME}" \
  --data-urlencode "pass=${OTP}" \
  || echo '')"

if [[ -z "$RESPONSE" ]]; then
  echo "ERROR: no se obtuvo respuesta de PrivacyIDEA"
  exit 2
fi

STATUS="$(echo "$RESPONSE" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("result", {}).get("value", False))
except Exception:
    print("parse_error")
')"

case "$STATUS" in
  True)
    echo "OK: PrivacyIDEA aceptó el OTP."
    exit 0
    ;;
  False)
    echo "RECHAZADO: PrivacyIDEA no aceptó el OTP."
    echo "Respuesta completa:"
    echo "$RESPONSE" | python3 -m json.tool
    exit 1
    ;;
  *)
    echo "ERROR: no se pudo parsear la respuesta."
    echo "Respuesta cruda: $RESPONSE"
    exit 2
    ;;
esac
