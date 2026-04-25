#!/usr/bin/env bash
#
# Verifica que privacyIDEA está operativo y, gradualmente, que el
# resolver LDAP y el realm quedan configurados. El script distingue
# dos estados aceptables:
#
#   - Servicio arriba, admin funciona, pero resolver/realm aún no
#     configurados: imprime PENDIENTE y termina en éxito (exit 0).
#
#   - Todo configurado: valida que el resolver vea 6 usuarios humanos
#     y termina con "Todo OK".
#
# Cualquier error real (servicio caído, admin no autentica, conteo
# distinto de 6) termina con código de salida distinto de cero.

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
RESOLVER_NAME="${PI_RESOLVER_NAME:-sia-ldap}"
REALM_NAME="${PI_REALM_NAME:-sia}"

echo "==> 1. Servicio responde en ${PI_URL}"
if ! curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/" -o /dev/null; then
  echo "ERROR: privacyIDEA no responde en ${PI_URL}"
  echo "Revisa que el contenedor esté arriba con: docker ps"
  exit 1
fi
echo "OK"

echo
echo "==> 2. Admin '${PI_ADMIN_USERNAME}' puede autenticarse"
AUTH_RESPONSE="$(curl "${PI_CURL_OPTS[@]}" -fsS -X POST "${PI_URL}/auth" \
  --data-urlencode "username=${PI_ADMIN_USERNAME}" \
  --data-urlencode "password=${PI_ADMIN_PASSWORD}" \
  || true)"

TOKEN="$(echo "$AUTH_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['result']['value']['token'])
except Exception:
    pass
")"

if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: no se obtuvo token de admin"
  echo "Respuesta cruda: ${AUTH_RESPONSE}"
  exit 1
fi
echo "OK: token de sesión obtenido"

AUTH_HEADER="Authorization: ${TOKEN}"

echo
echo "==> 3. Resolvers configurados"
RESOLVERS="$(curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/resolver/" -H "${AUTH_HEADER}" \
  | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(' '.join(data['result']['value'].keys()))
except Exception:
    pass
")"

if [[ -z "${RESOLVERS}" ]]; then
  echo "PENDIENTE: no hay resolvers configurados todavía."
  echo "Configúralos con: ./scripts/privacyidea-configure.sh"
  exit 0
fi
echo "Resolvers existentes: ${RESOLVERS}"

if ! echo "${RESOLVERS}" | grep -qw "${RESOLVER_NAME}"; then
  echo "PENDIENTE: resolver '${RESOLVER_NAME}' aún no existe."
  exit 0
fi

echo
echo "==> 4. Resolver '${RESOLVER_NAME}' encuentra exactamente 6 usuarios"
USER_COUNT="$(curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/user/?resolver=${RESOLVER_NAME}" -H "${AUTH_HEADER}" \
  | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(len(data['result']['value']))
except Exception:
    print('0')
")"

if [[ "${USER_COUNT}" != "6" ]]; then
  echo "ERROR: el resolver encontró ${USER_COUNT} usuarios, se esperaban 6."
  exit 1
fi
echo "OK: 6 usuarios humanos resueltos."

echo
echo "==> 5. Realm '${REALM_NAME}' configurado"
REALMS="$(curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/realm/" -H "${AUTH_HEADER}" \
  | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(' '.join(data['result']['value'].keys()))
except Exception:
    pass
")"

if ! echo "${REALMS}" | grep -qw "${REALM_NAME}"; then
  echo "PENDIENTE: realm '${REALM_NAME}' aún no existe."
  exit 0
fi
echo "OK"

echo
echo "Todo OK."
