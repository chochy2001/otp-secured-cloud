#!/usr/bin/env bash
# Verifica que OpenLDAP esté corriendo y tenga los usuarios esperados.
# Uso: ./scripts/ldap-verify.sh
#
# Requiere que exista .env en la raíz del repo y que el contenedor otpsec-openldap esté arriba.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env — cópialo desde .env.example primero."
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

echo "==> 1. Admin puede hacer bind y listar la raíz"
docker exec "$CONTAINER" ldapsearch -x -LLL \
  -H ldap://localhost \
  -b "${LDAP_BASE_DN}" \
  -D "cn=admin,${LDAP_BASE_DN}" \
  -w "${LDAP_ADMIN_PASSWORD}" \
  -s base dn

echo
echo "==> 2. Usuarios de Desarrollo"
docker exec "$CONTAINER" ldapsearch -x -LLL \
  -H ldap://localhost \
  -b "ou=Desarrollo,${LDAP_BASE_DN}" \
  -D "cn=admin,${LDAP_BASE_DN}" \
  -w "${LDAP_ADMIN_PASSWORD}" \
  "(objectClass=inetOrgPerson)" uid cn mail

echo
echo "==> 3. Usuarios de Seguridad"
docker exec "$CONTAINER" ldapsearch -x -LLL \
  -H ldap://localhost \
  -b "ou=Seguridad,${LDAP_BASE_DN}" \
  -D "cn=admin,${LDAP_BASE_DN}" \
  -w "${LDAP_ADMIN_PASSWORD}" \
  "(objectClass=inetOrgPerson)" uid cn mail

echo
echo "==> 4. Cuenta de servicio puede hacer bind (lo usarán OwnCloud y PrivacyIDEA)"
docker exec "$CONTAINER" ldapwhoami -x \
  -H ldap://localhost \
  -D "cn=svc-owncloud,ou=Servicios,${LDAP_BASE_DN}" \
  -w "${LDAP_SERVICE_PASSWORD}"

echo
echo "Todo OK."
