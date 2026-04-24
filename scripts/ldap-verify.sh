#!/usr/bin/env bash
# Verifica que OpenLDAP esté corriendo y tenga los usuarios esperados.
# Uso: ./scripts/ldap-verify.sh
#
# Requiere que exista .env en la raíz del repo y que el contenedor otpsec-openldap esté arriba.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env. Cópialo desde .env.example primero."
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

CONTAINER="otpsec-openldap"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: el contenedor ${CONTAINER} no está corriendo."
  echo "Arráncalo con:  cd compose && docker compose up -d openldap"
  exit 1
fi

ldap_search() {
  local base_dn="$1"
  local filter="$2"
  shift 2

  docker exec "$CONTAINER" ldapsearch -x -LLL \
    -H ldap://localhost \
    -b "$base_dn" \
    -D "cn=admin,${LDAP_BASE_DN}" \
    -w "$LDAP_ADMIN_PASSWORD" \
    "$filter" "$@"
}

count_entries() {
  local base_dn="$1"
  local filter="$2"

  ldap_search "$base_dn" "$filter" dn | grep -c '^dn: ' || true
}

assert_count() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: ${label} esperaba ${expected} entradas y encontró ${actual}."
    exit 1
  fi
}

echo "==> 1. Admin puede hacer bind y listar la raíz"
docker exec "$CONTAINER" ldapsearch -x -LLL \
  -H ldap://localhost \
  -b "${LDAP_BASE_DN}" \
  -D "cn=admin,${LDAP_BASE_DN}" \
  -w "${LDAP_ADMIN_PASSWORD}" \
  -s base dn

echo
echo "==> 2. Usuarios de Desarrollo"
ldap_search "ou=Desarrollo,${LDAP_BASE_DN}" "(objectClass=inetOrgPerson)" uid cn mail
assert_count "Desarrollo" "3" "$(count_entries "ou=Desarrollo,${LDAP_BASE_DN}" "(objectClass=inetOrgPerson)")"

echo
echo "==> 3. Usuarios de Seguridad"
ldap_search "ou=Seguridad,${LDAP_BASE_DN}" "(objectClass=inetOrgPerson)" uid cn mail
assert_count "Seguridad" "3" "$(count_entries "ou=Seguridad,${LDAP_BASE_DN}" "(objectClass=inetOrgPerson)")"

echo
echo "==> 4. Filtro de usuarios humanos no incluye cuentas de servicio"
assert_count "usuarios humanos" "6" "$(count_entries "${LDAP_BASE_DN}" "(objectClass=inetOrgPerson)")"
echo "OK: el filtro inetOrgPerson devuelve exactamente 6 usuarios."

echo
echo "==> 5. Cuenta de servicio puede hacer bind (lo usarán OwnCloud y PrivacyIDEA)"
docker exec "$CONTAINER" ldapwhoami -x \
  -H ldap://localhost \
  -D "cn=svc-owncloud,ou=Servicios,${LDAP_BASE_DN}" \
  -w "${LDAP_SERVICE_PASSWORD}"

echo
echo "==> 6. Contraseña incorrecta se rechaza"
set +e
docker exec "$CONTAINER" ldapwhoami -x \
  -H ldap://localhost \
  -D "uid=usuario.desarrollo1,ou=Desarrollo,${LDAP_BASE_DN}" \
  -w "contrasena-incorrecta" >/dev/null 2>&1
INVALID_STATUS=$?
set -e

if [[ "$INVALID_STATUS" -eq 0 ]]; then
  echo "ERROR: LDAP aceptó una contraseña incorrecta."
  exit 1
fi

echo "OK: credenciales inválidas rechazadas."

echo
echo "Todo OK."
