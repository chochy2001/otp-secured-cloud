#!/usr/bin/env bash
#
# Configura OwnCloud de forma idempotente:
# user_ldap por LDAPS, privacyIDEA como segundo factor y cifrado local.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/.env"
OWNCLOUD_CONTAINER="otpsec-owncloud-server"
LDAP_CONFIG_ID="s01"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: no existe ${ENV_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

occ() {
  docker exec "${OWNCLOUD_CONTAINER}" occ "$@"
}

wait_for_owncloud() {
  local attempts=60

  while (( attempts > 0 )); do
    if docker exec "${OWNCLOUD_CONTAINER}" occ status >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    attempts=$((attempts - 1))
  done

  echo "ERROR: OwnCloud no quedó listo a tiempo."
  echo "Revisa logs con: docker logs ${OWNCLOUD_CONTAINER}"
  exit 1
}

set_ldap_config() {
  local key="$1"
  local value="$2"
  occ ldap:set-config "${LDAP_CONFIG_ID}" "${key}" "${value}" >/dev/null
}

set_app_config() {
  local app="$1"
  local key="$2"
  local value="$3"
  occ config:app:set "${app}" "${key}" --value="${value}" >/dev/null
}

echo "==> 1. Levantando servicios de OwnCloud"
compose up -d openldap privacyidea owncloud-db owncloud-redis owncloud-server owncloud-proxy
wait_for_owncloud
echo "OK"

echo
echo "==> 2. Habilitando LDAP Integration"
occ app:enable user_ldap >/dev/null || true

if ! occ ldap:show-config "${LDAP_CONFIG_ID}" >/dev/null 2>&1; then
  occ ldap:create-empty-config "${LDAP_CONFIG_ID}" >/dev/null
fi

set_ldap_config ldapHost "ldaps://openldap"
set_ldap_config ldapPort "636"
set_ldap_config ldapBase "${LDAP_BASE_DN}"
set_ldap_config ldapBaseUsers "ou=Usuarios,${LDAP_BASE_DN}"
set_ldap_config ldapBaseGroups "ou=Grupos,${LDAP_BASE_DN}"
set_ldap_config ldapAgentName "cn=svc-owncloud,ou=Servicios,${LDAP_BASE_DN}"
set_ldap_config ldapAgentPassword "${LDAP_SERVICE_PASSWORD}"
set_ldap_config ldapTLS "0"
set_ldap_config turnOffCertCheck "0"
set_ldap_config ldapUserFilter "(&(objectClass=inetOrgPerson)(uid=*))"
set_ldap_config ldapLoginFilter "(&(objectClass=inetOrgPerson)(uid=%uid))"
set_ldap_config ldapGroupFilter "(objectClass=groupOfNames)"
set_ldap_config ldapUserDisplayName "cn"
set_ldap_config ldapUserName "uid"
set_ldap_config ldapEmailAttribute "mail"
set_ldap_config ldapExpertUUIDUserAttr "entryUUID"
set_ldap_config ldapExpertUsernameAttr "uid"
set_ldap_config ldapAttributesForUserSearch "uid;cn;mail"
set_ldap_config ldapConfigurationActive "1"

if ! occ ldap:test-config "${LDAP_CONFIG_ID}" | grep -qi "configuration is valid"; then
  echo "ERROR: la configuración LDAP de OwnCloud no es válida."
  occ ldap:test-config "${LDAP_CONFIG_ID}" || true
  exit 1
fi
echo "OK"

echo
echo "==> 3. Instalando y configurando privacyIDEA para OwnCloud"
if ! occ app:list | grep -q "twofactor_privacyidea"; then
  occ market:install twofactor_privacyidea >/dev/null
fi
occ app:enable twofactor_privacyidea >/dev/null || true

set_app_config twofactor_privacyidea url "https://privacyidea:8443/"
set_app_config twofactor_privacyidea checkssl "1"
set_app_config twofactor_privacyidea piactive "1"
set_app_config twofactor_privacyidea pitimeout "10"
set_app_config twofactor_privacyidea realm "${PI_REALM_NAME:-sia}"
set_app_config twofactor_privacyidea triggerchallenges "0"
set_app_config twofactor_privacyidea serviceaccount_user "${PI_ADMIN_USERNAME}"
set_app_config twofactor_privacyidea serviceaccount_password "${PI_ADMIN_PASSWORD}"
set_app_config twofactor_privacyidea passOnNoUser "0"
set_app_config twofactor_privacyidea autoSubmitOtpLength "6"
set_app_config twofactor_privacyidea noproxy "1"
set_app_config twofactor_privacyidea piexclude "1"
set_app_config twofactor_privacyidea piexcludegroups ""
echo "OK"

echo
echo "==> 4. Activando cifrado local con master key"
occ app:enable encryption >/dev/null || true
if ! occ encryption:status | grep -qi "enabled: true"; then
  occ encryption:enable >/dev/null
fi
echo "OK"

echo
echo "==> 5. Sincronizando usuarios LDAP"
occ user:sync "OCA\\User_LDAP\\User_Proxy" -m disable -vvv

echo
echo "Configuración de OwnCloud completa. Ejecuta ./scripts/owncloud-verify.sh para validar."
