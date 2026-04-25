# Helper de curl para los scripts que hablan con privacyIDEA.
# No es ejecutable: se usa con `source` desde otros scripts.
#
# Define el array PI_CURL_OPTS con las opciones que se le tienen que
# pasar a curl cuando PI_URL es HTTPS, para que confie en la CA del
# proyecto en lugar de fallar por certificado autofirmado.
#
# Requisitos previos en el script que invoca:
#   - ROOT_DIR ya esta seteado al directorio raiz del repo.
#   - PI_URL ya viene cargado del .env.
#   - PI_CA_BUNDLE es la ruta relativa al bundle de la CA (opcional).
#
# Uso tipico:
#   ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   source "$ROOT_DIR/.env"
#   source "$ROOT_DIR/scripts/lib-curl.sh"
#   curl "${PI_CURL_OPTS[@]}" -fsS "${PI_URL}/auth" ...

PI_CURL_OPTS=()

PI_CA_PATH="${ROOT_DIR}/${PI_CA_BUNDLE:-}"
if [[ "${PI_URL:-}" == https://* ]] && [[ -f "${PI_CA_PATH}" ]]; then
  PI_CURL_OPTS+=(--cacert "${PI_CA_PATH}")
fi
