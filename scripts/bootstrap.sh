#!/usr/bin/env bash
#
# Arranque completo del laboratorio desde un clone limpio.
# Genera certificados, levanta Docker Compose, configura servicios y
# ejecuta la batería evaluable de pruebas end-to-end.
#
# Uso:
#   ./scripts/bootstrap.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/compose/docker-compose.yml"
ENV_FILE="${ROOT_DIR}/.env"

BUILD_IMAGES=true
RUN_TESTS=true
RUN_AUDIT=false

CONTAINERS=(
  otpsec-openldap
  otpsec-privacyidea
  otpsec-owncloud-db
  otpsec-owncloud-redis
  otpsec-owncloud-server
  otpsec-owncloud-proxy
)

usage() {
  cat <<'EOF'
Uso: ./scripts/bootstrap.sh [opciones]

Opciones:
  --no-build     No reconstruye imágenes; solo levanta contenedores.
  --skip-tests   Levanta y configura el stack, pero omite validaciones.
  --with-audit   También regenera docs/auditoria.md al final.
  -h, --help     Muestra esta ayuda.
EOF
}

while (( $# > 0 )); do
  case "$1" in
    --no-build)
      BUILD_IMAGES=false
      ;;
    --skip-tests)
      RUN_TESTS=false
      ;;
    --with-audit)
      RUN_AUDIT=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: opción no reconocida: $1"
      usage
      exit 2
      ;;
  esac
  shift
done

cd "${ROOT_DIR}"

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: falta el comando '${cmd}'. Instala el prerrequisito y reintenta."
    exit 1
  fi
}

section() {
  echo
  echo "==> $*"
}

run_step() {
  local title="$1"
  shift
  section "${title}"
  "$@"
}

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

health_status() {
  local container="$1"
  docker inspect -f '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health{{end}}' "${container}" 2>/dev/null || true
}

wait_for_healthy() {
  local timeout_seconds="${1:-420}"
  local deadline=$((SECONDS + timeout_seconds))
  local pending=()
  local container status

  section "Esperando contenedores healthy"
  while (( SECONDS < deadline )); do
    pending=()
    for container in "${CONTAINERS[@]}"; do
      status="$(health_status "${container}")"
      if [[ "${status}" != "running/healthy" ]]; then
        pending+=("${container}:${status:-missing}")
      fi
    done

    if (( ${#pending[@]} == 0 )); then
      echo "OK: todos los contenedores están healthy."
      return 0
    fi

    printf 'Aún iniciando: %s\n' "${pending[*]}"
    sleep 5
  done

  echo "ERROR: algún contenedor no quedó healthy antes de ${timeout_seconds}s."
  compose ps || true
  echo
  echo "Últimas líneas de logs por contenedor:"
  for container in "${CONTAINERS[@]}"; do
    echo
    echo "--- ${container} ---"
    docker logs --tail 80 "${container}" 2>&1 || true
  done
  exit 1
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: no existe ${ENV_FILE}. El repo debe incluir .env para reproducibilidad académica."
  exit 1
fi

require_cmd docker
require_cmd curl
require_cmd openssl
require_cmd python3

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose v2 no está disponible como 'docker compose'."
  exit 1
fi

run_step "Generando certificados locales" ./scripts/generate-certs.sh

section "Levantando stack Docker"
if [[ "${BUILD_IMAGES}" == "true" ]]; then
  compose up -d --build
else
  compose up -d
fi
wait_for_healthy 420

run_step "Configurando privacyIDEA" ./scripts/privacyidea-configure.sh
run_step "Configurando OwnCloud" ./scripts/owncloud-configure.sh
wait_for_healthy 420

if [[ "${RUN_TESTS}" == "true" ]]; then
  run_step "Validando OpenLDAP" ./scripts/ldap-verify.sh
  run_step "Validando privacyIDEA" ./scripts/privacyidea-verify.sh
  run_step "Validando OwnCloud" ./scripts/owncloud-verify.sh
  run_step "Validando login LDAP + OTP y cifrado" ./scripts/owncloud-login-verify.sh usuario.desarrollo1
  run_step "Validando carpetas compartidas" ./scripts/owncloud-share-verify.sh usuario.desarrollo1 usuario.seguridad1
fi

if [[ "${RUN_AUDIT}" == "true" ]]; then
  run_step "Regenerando auditoría" ./scripts/audit-capture.sh
fi

if [[ "${RUN_TESTS}" == "true" ]]; then
  FINAL_STATUS="levantado, configurado y validado"
else
  FINAL_STATUS="levantado y configurado; pruebas omitidas por --skip-tests"
fi

cat <<EOF

Listo: el laboratorio quedó ${FINAL_STATUS}.

Servicios:
  OwnCloud:     https://localhost:9443
  privacyIDEA:  https://localhost:8443
  OpenLDAP:     localhost:389 y LDAPS localhost:6636

Para apagar sin borrar datos:
  docker compose -f compose/docker-compose.yml --env-file .env down
EOF
