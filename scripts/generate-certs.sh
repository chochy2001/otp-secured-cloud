#!/usr/bin/env bash
#
# Genera la CA del proyecto y los certificados de servidor para
# OpenLDAP y PrivacyIDEA.
#
# Idempotente: si la CA o un cert ya existen, no se regenera. Para
# forzar la regeneración pasar el flag --force.
#
# Salida:
#   certs/ca.key, certs/ca.crt
#   certs/openldap.key, certs/openldap.crt
#   certs/privacyidea.key, certs/privacyidea.crt
#
# Las llaves privadas (.key) están listadas en .gitignore y NO deben
# subirse al repositorio. Solo se versionan ejemplos de configuración.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERTS_DIR="${ROOT_DIR}/certs"

CA_DAYS=3650
SERVER_DAYS=825
CA_SUBJECT="/C=MX/ST=CDMX/L=CDMX/O=SIA UNAM FI/OU=Proyecto Final/CN=otp-secured-cloud Local CA"

FORCE="false"
if [[ "${1:-}" == "--force" ]]; then
  FORCE="true"
fi

mkdir -p "${CERTS_DIR}"

CA_KEY="${CERTS_DIR}/ca.key"
CA_CRT="${CERTS_DIR}/ca.crt"
CA_SRL="${CERTS_DIR}/ca.srl"

if [[ "${FORCE}" == "true" ]] || [[ ! -f "${CA_KEY}" ]] || [[ ! -f "${CA_CRT}" ]]; then
  echo "[ca] Generando CA del proyecto (RSA 4096, ${CA_DAYS} dias)"
  openssl req -x509 -newkey rsa:4096 -sha256 \
    -keyout "${CA_KEY}" -out "${CA_CRT}" \
    -days "${CA_DAYS}" -nodes \
    -subj "${CA_SUBJECT}"
  chmod 600 "${CA_KEY}"
  chmod 644 "${CA_CRT}"
else
  echo "[ca] La CA ya existe en ${CA_KEY}, no se regenera (usar --force para reemplazar)."
fi

generate_server_cert() {
  local name="$1"
  local sans="$2"

  local key="${CERTS_DIR}/${name}.key"
  local csr="${CERTS_DIR}/${name}.csr"
  local crt="${CERTS_DIR}/${name}.crt"
  local extfile="${CERTS_DIR}/${name}.ext"

  if [[ "${FORCE}" != "true" ]] && [[ -f "${key}" ]] && [[ -f "${crt}" ]]; then
    echo "[${name}] El certificado ya existe, no se regenera."
    return
  fi

  echo "[${name}] Generando llave y certificado firmado por la CA"

  openssl req -newkey rsa:2048 -nodes -sha256 \
    -keyout "${key}" -out "${csr}" \
    -subj "/C=MX/ST=CDMX/L=CDMX/O=SIA UNAM FI/OU=Proyecto Final/CN=${name}"

  cat > "${extfile}" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = ${sans}
EOF

  openssl x509 -req -in "${csr}" -sha256 \
    -CA "${CA_CRT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${crt}" -days "${SERVER_DAYS}" \
    -extfile "${extfile}"

  chmod 600 "${key}"
  chmod 644 "${crt}"
  rm -f "${csr}" "${extfile}"
}

generate_server_cert "openldap"    "DNS:openldap,DNS:localhost,IP:127.0.0.1,IP:::1"
generate_server_cert "privacyidea" "DNS:privacyidea,DNS:localhost,IP:127.0.0.1,IP:::1"

echo
echo "Resumen:"
ls -l "${CERTS_DIR}" | grep -E '\.(crt|key|srl)$' || true

echo
echo "La CA y las llaves privadas estan ignoradas por git (ver .gitignore)."
echo "Para confiar en los certificados desde curl: --cacert ${CA_CRT}"
