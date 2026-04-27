#!/usr/bin/env bash
#
# Entrypoint de privacyIDEA. Idempotente: crea solo lo que falta.
# En el primer arranque genera llaves, esquema de base de datos y
# admin inicial. En arranques posteriores detecta que ya existen
# y no los recrea.

set -euo pipefail

: "${PI_ADMIN_USERNAME:?PI_ADMIN_USERNAME es requerido}"
: "${PI_ADMIN_PASSWORD:?PI_ADMIN_PASSWORD es requerido}"
: "${PI_PEPPER:?PI_PEPPER es requerido}"
: "${PI_SECRET_KEY:?PI_SECRET_KEY es requerido}"

DATA_DIR="${DATA_DIR:-/data}"
mkdir -p "${DATA_DIR}" /var/log/privacyidea

if [[ ! -f "${DATA_DIR}/enckey" ]]; then
  echo "[init] Generando llave de cifrado en ${DATA_DIR}/enckey"
  pi-manage setup create_enckey
fi

if [[ ! -f "${DATA_DIR}/private.pem" ]] || [[ ! -f "${DATA_DIR}/public.pem" ]]; then
  echo "[init] Generando llaves de auditoría en ${DATA_DIR}"
  pi-manage setup create_audit_keys
fi

# create_tables es idempotente (usa SQLAlchemy create_all, que solo
# crea tablas que no existan). Se corre siempre porque el archivo
# pi.db puede existir como side effect de create_enckey o similares
# sin tener el esquema completo adentro.
echo "[init] Asegurando esquema de base de datos en ${DATA_DIR}/pi.db"
pi-manage setup create_tables

# Se comprueba que el admin exista listandolo; si la lista no contiene
# el username, se crea. Evita ejecutar 'admin add' cuando ya existe.
if ! pi-manage admin list 2>/dev/null | awk '{print $1}' | grep -qxF "${PI_ADMIN_USERNAME}"; then
  echo "[init] Creando admin inicial '${PI_ADMIN_USERNAME}'"
  pi-manage admin add "${PI_ADMIN_USERNAME}" -p "${PI_ADMIN_PASSWORD}"
else
  echo "[init] Admin '${PI_ADMIN_USERNAME}' ya existe, no se recrea."
fi

SSL_DIR="/etc/privacyidea/ssl"
SSL_CRT="${SSL_DIR}/server.crt"
SSL_KEY="${SSL_DIR}/server.key"

case "${1:-serve}" in
  serve)
    if [[ ! -f "${SSL_CRT}" ]] || [[ ! -f "${SSL_KEY}" ]]; then
      echo "ERROR: no se encontró cert TLS en ${SSL_DIR}."
      echo "Genera los certs desde la raíz del repo con: ./scripts/generate-certs.sh"
      exit 1
    fi

    echo "[run] Levantando servidor HTTPS en 0.0.0.0:8443"
    exec pi-manage run \
      -h 0.0.0.0 -p 8443 \
      --cert="${SSL_CRT}" \
      --key="${SSL_KEY}"
    ;;
  manage)
    shift
    exec pi-manage "$@"
    ;;
  *)
    exec "$@"
    ;;
esac
