#!/usr/bin/env bash
#
# Verifica que privacyIDEA está operativo y completamente configurado:
# servicio HTTPS, admin, resolver LDAP por LDAPS, conteo de usuarios y realm.
# Cualquier faltante termina con código de salida distinto de cero.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

PI_URL="${PI_URL:-https://localhost:8443}"

# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/lib-curl.sh"

RESOLVER_NAME="${PI_RESOLVER_NAME:-sia-ldap}"
REALM_NAME="${PI_REALM_NAME:-sia}"
LDAP_RESOLVER_URI="${PI_LDAP_URI:-ldaps://openldap:636}"
LDAP_TLS_CA_FILE="${PI_LDAP_TLS_CA_FILE:-/etc/privacyidea/ssl/ca.crt}"

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
  echo "ERROR: no hay resolvers configurados todavía."
  echo "Configúralos con: ./scripts/privacyidea-configure.sh"
  exit 1
fi
echo "Resolvers existentes: ${RESOLVERS}"

if ! echo "${RESOLVERS}" | grep -qw "${RESOLVER_NAME}"; then
  echo "ERROR: resolver '${RESOLVER_NAME}' aún no existe."
  exit 1
fi

echo
echo "==> 4. Resolver '${RESOLVER_NAME}' usa LDAPS y valida la CA"
RESOLVER_CONFIG="$(curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/resolver/${RESOLVER_NAME}" -H "${AUTH_HEADER}")"
RESOLVER_TLS_SUMMARY="$(echo "${RESOLVER_CONFIG}" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    resolver = data['result']['value']['${RESOLVER_NAME}']['data']
    print('|'.join([
        resolver.get('LDAPURI', ''),
        resolver.get('TLS_VERIFY', ''),
        resolver.get('TLS_CA_FILE', ''),
        resolver.get('TLS_VERSION', ''),
    ]))
except Exception:
    pass
")"

IFS='|' read -r CONFIGURED_LDAP_URI CONFIGURED_TLS_VERIFY CONFIGURED_TLS_CA_FILE CONFIGURED_TLS_VERSION <<< "${RESOLVER_TLS_SUMMARY}"

if [[ "${CONFIGURED_LDAP_URI}" != "${LDAP_RESOLVER_URI}" ]]; then
  echo "ERROR: el resolver usa '${CONFIGURED_LDAP_URI}', se esperaba '${LDAP_RESOLVER_URI}'."
  exit 1
fi

if [[ "${CONFIGURED_TLS_VERIFY}" != "True" ]]; then
  echo "ERROR: el resolver no tiene TLS_VERIFY=True."
  exit 1
fi

if [[ "${CONFIGURED_TLS_CA_FILE}" != "${LDAP_TLS_CA_FILE}" ]]; then
  echo "ERROR: el resolver usa TLS_CA_FILE='${CONFIGURED_TLS_CA_FILE}', se esperaba '${LDAP_TLS_CA_FILE}'."
  exit 1
fi

if [[ "${CONFIGURED_TLS_VERSION}" != "5" ]]; then
  echo "ERROR: el resolver usa TLS_VERSION='${CONFIGURED_TLS_VERSION}', se esperaba '5' (TLS 1.2)."
  exit 1
fi
echo "OK: ${CONFIGURED_LDAP_URI} con CA ${CONFIGURED_TLS_CA_FILE} y TLS 1.2"

echo
echo "==> 5. Resolver '${RESOLVER_NAME}' encuentra exactamente 6 usuarios"
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
echo "==> 6. Realm '${REALM_NAME}' configurado"
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
  echo "ERROR: realm '${REALM_NAME}' aún no existe."
  exit 1
fi
echo "OK"

echo
echo "Todo OK."
