#!/usr/bin/env bash
#
# Verifica OwnCloud, LDAP por LDAPS, privacyIDEA 2FA y cifrado local.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
OWNCLOUD_CONTAINER="otpsec-owncloud-server"
LDAP_CONFIG_ID="s01"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: no existe ${ENV_FILE}"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

OC_URL="${OC_URL:-https://localhost:9443}"
OC_CA_BUNDLE="${OC_CA_BUNDLE:-certs/ca.crt}"

occ() {
  docker exec "${OWNCLOUD_CONTAINER}" occ "$@"
}

echo "==> 1. OwnCloud responde en ${OC_URL}"
curl -fsS --cacert "${ROOT_DIR}/${OC_CA_BUNDLE}" "${OC_URL}/status.php" -o /dev/null
echo "OK"

echo
echo "==> 2. OwnCloud está instalado"
STATUS="$(occ status)"
echo "${STATUS}"
if ! echo "${STATUS}" | grep -q "installed: true"; then
  echo "ERROR: OwnCloud no aparece como instalado."
  exit 1
fi
echo "OK"

echo
echo "==> 3. LDAP Integration usa LDAPS y valida certificados"
LDAP_JSON="$(occ ldap:show-config "${LDAP_CONFIG_ID}" --output=json_pretty)"
LDAP_SUMMARY="$(echo "${LDAP_JSON}" | python3 -c '
import json, sys
data = json.load(sys.stdin)
def value(name):
    item = data.get(name, "")
    if isinstance(item, list):
        return item[0] if item else ""
    return item
print("|".join([
    value("ldapHost"),
    value("ldapPort"),
    value("ldapBaseUsers"),
    value("ldapAgentName"),
    value("turnOffCertCheck"),
    value("ldapConfigurationActive"),
]))
')"
IFS='|' read -r LDAP_HOST LDAP_PORT LDAP_BASE_USERS LDAP_AGENT_NAME TURN_OFF_CERT_CHECK LDAP_ACTIVE <<< "${LDAP_SUMMARY}"

if [[ "${LDAP_HOST}" != "ldaps://openldap" || "${LDAP_PORT}" != "636" ]]; then
  echo "ERROR: LDAP no está configurado por LDAPS interno."
  exit 1
fi

if [[ "${LDAP_BASE_USERS}" != "ou=Usuarios,${LDAP_BASE_DN}" ]]; then
  echo "ERROR: ldapBaseUsers inesperado: ${LDAP_BASE_USERS}"
  exit 1
fi

if [[ "${LDAP_AGENT_NAME}" != "cn=svc-owncloud,ou=Servicios,${LDAP_BASE_DN}" ]]; then
  echo "ERROR: bind DN inesperado: ${LDAP_AGENT_NAME}"
  exit 1
fi

if [[ "${TURN_OFF_CERT_CHECK}" != "0" ]]; then
  echo "ERROR: OwnCloud tiene desactivada la validación de certificado LDAP."
  exit 1
fi

if [[ "${LDAP_ACTIVE}" != "1" ]]; then
  echo "ERROR: configuración LDAP inactiva."
  exit 1
fi

if ! occ ldap:test-config "${LDAP_CONFIG_ID}" | grep -qi "configuration is valid"; then
  echo "ERROR: ldap:test-config falló."
  exit 1
fi
echo "OK"

echo
echo "==> 4. OwnCloud resuelve exactamente 6 usuarios LDAP"
USER_COUNT="$(occ ldap:search "usuario" --limit=20 | grep -cE '^Usuario ' || true)"
if [[ "${USER_COUNT}" != "6" ]]; then
  echo "ERROR: OwnCloud encontró ${USER_COUNT} usuarios LDAP, se esperaban 6."
  exit 1
fi
echo "OK: 6 usuarios"

echo
echo "==> 5. App privacyIDEA activa y apuntando a HTTPS interno"
# Capturar la salida en una variable evita el SIGPIPE que produce
# `occ app:list | grep -q ...` cuando `grep` encuentra la coincidencia
# antes de que `occ` termine de escribir. Con `set -o pipefail` ese
# SIGPIPE se traducía en un falso error aunque el plugin sí estuviera.
APP_LIST="$(occ app:list 2>&1)"
if ! printf '%s' "${APP_LIST}" | grep -q "twofactor_privacyidea"; then
  echo "ERROR: twofactor_privacyidea no está disponible."
  exit 1
fi

PI_APP_URL="$(occ config:app:get twofactor_privacyidea url)"
PI_APP_SSL="$(occ config:app:get twofactor_privacyidea checkssl)"
PI_APP_ACTIVE="$(occ config:app:get twofactor_privacyidea piactive)"
PI_APP_REALM="$(occ config:app:get twofactor_privacyidea realm)"
PI_APP_EXCLUDE="$(occ config:app:get twofactor_privacyidea piexclude)"
PI_APP_EXCLUDE_GROUPS="$(occ config:app:get twofactor_privacyidea piexcludegroups)"

if [[ "${PI_APP_URL}" != "https://privacyidea:8443/" ]]; then
  echo "ERROR: URL privacyIDEA inesperada: ${PI_APP_URL}"
  exit 1
fi

if [[ "${PI_APP_SSL}" != "1" || "${PI_APP_ACTIVE}" != "1" ]]; then
  echo "ERROR: privacyIDEA no valida SSL o no está activa."
  exit 1
fi

if [[ "${PI_APP_REALM}" != "${PI_REALM_NAME:-sia}" ]]; then
  echo "ERROR: realm privacyIDEA inesperado: ${PI_APP_REALM}"
  exit 1
fi

if [[ "${PI_APP_EXCLUDE}" != "1" || "${PI_APP_EXCLUDE_GROUPS}" != "admin" ]]; then
  echo "ERROR: exclusión de admin inesperada: piexclude=${PI_APP_EXCLUDE}, piexcludegroups=${PI_APP_EXCLUDE_GROUPS}"
  exit 1
fi

docker exec "${OWNCLOUD_CONTAINER}" curl -fsS https://privacyidea:8443/ -o /dev/null
echo "OK"

echo
echo "==> 6. Cifrado del lado servidor activo"
ENCRYPTION_STATUS="$(occ encryption:status)"
echo "${ENCRYPTION_STATUS}"
if ! echo "${ENCRYPTION_STATUS}" | grep -qi "enabled: true"; then
  echo "ERROR: cifrado no está activo."
  exit 1
fi
USE_MASTER_KEY="$(occ config:app:get encryption useMasterKey)"
if [[ "${USE_MASTER_KEY}" != "1" ]]; then
  echo "ERROR: OwnCloud no reporta cifrado en modo master key."
  exit 1
fi
echo "OK: master key activa"

echo
echo "Todo OK."
