#!/usr/bin/env bash
#
# Configura el resolver LDAP y el realm de privacyIDEA de forma idempotente.
# Uso: ./scripts/privacyidea-configure.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

PI_URL="${PI_URL:-http://localhost:8080}"
RESOLVER_NAME="${PI_RESOLVER_NAME:-sia-ldap}"
REALM_NAME="${PI_REALM_NAME:-sia}"
LDAP_FILTER="(objectClass=inetOrgPerson)"
LDAP_LOGIN_FILTER="(&(uid={login})(objectClass=inetOrgPerson))"
LDAP_USERINFO='{"username": "uid", "uid": "uid", "givenname": "givenName", "surname": "sn", "email": "mail", "phone": "telephoneNumber", "mobile": "mobile"}'

require_success() {
  local label="$1"
  local response="$2"

  if ! echo "$response" | python3 -c '
import json, sys
data = json.load(sys.stdin)
result = data.get("result", {})
sys.exit(0 if result.get("status") is True else 1)
'; then
    echo "ERROR: ${label} falló"
    echo "Respuesta cruda: ${response}"
    exit 1
  fi
}

echo "==> 1. privacyIDEA responde en ${PI_URL}"
curl -fsS "${PI_URL}/" -o /dev/null
echo "OK"

echo
echo "==> 2. Autenticando admin '${PI_ADMIN_USERNAME}'"
AUTH_RESPONSE="$(curl -fsS -X POST "${PI_URL}/auth" \
  --data-urlencode "username=${PI_ADMIN_USERNAME}" \
  --data-urlencode "password=${PI_ADMIN_PASSWORD}")"

TOKEN="$(echo "$AUTH_RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data.get("result", {}).get("value", {}).get("token", ""))
')"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: no se obtuvo token de admin"
  echo "Respuesta cruda: ${AUTH_RESPONSE}"
  exit 1
fi
echo "OK"

AUTH_HEADERS=(-H "Authorization: ${TOKEN}" -H "PI-Authorization: ${TOKEN}")

echo
echo "==> 3. Creando o actualizando resolver LDAP '${RESOLVER_NAME}'"
RESOLVER_RESPONSE="$(curl -fsS -X POST "${PI_URL}/resolver/${RESOLVER_NAME}" \
  "${AUTH_HEADERS[@]}" \
  --data-urlencode "type=ldapresolver" \
  --data-urlencode "LDAPURI=ldap://openldap" \
  --data-urlencode "LDAPBASE=${LDAP_BASE_DN}" \
  --data-urlencode "AUTHTYPE=Simple" \
  --data-urlencode "BINDDN=cn=svc-owncloud,ou=Servicios,${LDAP_BASE_DN}" \
  --data-urlencode "BINDPW=${LDAP_SERVICE_PASSWORD}" \
  --data-urlencode "TIMEOUT=5" \
  --data-urlencode "CACHE_TIMEOUT=120" \
  --data-urlencode "SIZELIMIT=500" \
  --data-urlencode "LOGINNAMEATTRIBUTE=uid" \
  --data-urlencode "LDAPSEARCHFILTER=${LDAP_FILTER}" \
  --data-urlencode "LDAPFILTER=${LDAP_LOGIN_FILTER}" \
  --data-urlencode "USERINFO=${LDAP_USERINFO}" \
  --data-urlencode "UIDTYPE=entryUUID" \
  --data-urlencode "NOREFERRALS=True" \
  --data-urlencode "START_TLS=False" \
  --data-urlencode "TLS_VERIFY=False")"
require_success "configuración del resolver" "$RESOLVER_RESPONSE"
echo "OK"

echo
echo "==> 4. Creando o actualizando realm '${REALM_NAME}'"
REALM_RESPONSE="$(curl -fsS -X POST "${PI_URL}/realm/${REALM_NAME}" \
  "${AUTH_HEADERS[@]}" \
  --data-urlencode "resolvers=${RESOLVER_NAME}" \
  --data-urlencode "priority.${RESOLVER_NAME}=1")"
require_success "configuración del realm" "$REALM_RESPONSE"
echo "OK"

echo
echo "==> 5. Marcando '${REALM_NAME}' como realm por defecto"
DEFAULT_RESPONSE="$(curl -fsS -X POST "${PI_URL}/defaultrealm/${REALM_NAME}" \
  "${AUTH_HEADERS[@]}")"
require_success "configuración del realm por defecto" "$DEFAULT_RESPONSE"
echo "OK"

echo
echo "Configuración completa. Ejecuta ./scripts/privacyidea-verify.sh para validar el conteo de usuarios."
