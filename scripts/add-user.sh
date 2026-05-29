#!/usr/bin/env bash
#
# Crea un usuario nuevo en el directorio OpenLDAP que ya está corriendo.
#
# Hashea la contraseña con slappasswd ({SSHA}), arma el LDIF, lo aplica con
# ldapadd contra cn=admin y verifica que la entrada quedó creada. Opcionalmente
# siembra el mismo usuario en los LDIF de bootstrap para que sobreviva a un
# "docker compose down -v".
#
# Uso:
#   ./scripts/add-user.sh --uid usuario.desarrollo4 \
#                         --nombre "Usuario Desarrollo Cuatro" \
#                         --apellido Desarrollo \
#                         --ou Desarrollo \
#                         --password "una-contrasena"
#
# Flags:
#   -u, --uid        uid del usuario (requerido). Ej: usuario.desarrollo4
#   -n, --nombre     cn / nombre completo (requerido). Ej: "Usuario Desarrollo Cuatro"
#   -s, --apellido   sn / apellido (requerido). Ej: Desarrollo
#   -o, --ou         OU destino: Desarrollo | Seguridad (requerido)
#   -p, --password   contraseña en texto plano (requerido; se guarda hasheada)
#   -g, --given      givenName (opcional; default: igual que --nombre)
#   -m, --mail       correo (opcional; default: <uid>@<LDAP_DOMAIN>)
#       --bootstrap  además, agrega el usuario al LDIF de bootstrap correspondiente
#   -h, --help       muestra esta ayuda
#
# Requiere .env en la raíz del repo y el contenedor otpsec-openldap arriba.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="otpsec-openldap"

usage() {
  # Imprime el bloque de comentarios del encabezado hasta la primera línea no comentada.
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
  exit "${1:-0}"
}

# --- Parseo de flags ---------------------------------------------------------
UID_VAL=""
NOMBRE=""
APELLIDO=""
OU=""
PASSWORD=""
GIVEN=""
MAIL=""
SEED_BOOTSTRAP="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--uid)        UID_VAL="${2:-}"; shift 2 ;;
    -n|--nombre)     NOMBRE="${2:-}"; shift 2 ;;
    -s|--apellido)   APELLIDO="${2:-}"; shift 2 ;;
    -o|--ou)         OU="${2:-}"; shift 2 ;;
    -p|--password)   PASSWORD="${2:-}"; shift 2 ;;
    -g|--given)      GIVEN="${2:-}"; shift 2 ;;
    -m|--mail)       MAIL="${2:-}"; shift 2 ;;
    --bootstrap)     SEED_BOOTSTRAP="true"; shift ;;
    -h|--help)       usage 0 ;;
    *) echo "ERROR: flag desconocido: $1"; echo; usage 1 ;;
  esac
done

# --- Validaciones de entrada -------------------------------------------------
missing=()
[[ -z "$UID_VAL" ]]   && missing+=("--uid")
[[ -z "$NOMBRE" ]]    && missing+=("--nombre")
[[ -z "$APELLIDO" ]]  && missing+=("--apellido")
[[ -z "$OU" ]]        && missing+=("--ou")
[[ -z "$PASSWORD" ]]  && missing+=("--password")
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: faltan flags requeridos: ${missing[*]}"
  echo
  usage 1
fi

case "$OU" in
  Desarrollo|Seguridad) ;;
  *) echo "ERROR: --ou debe ser 'Desarrollo' o 'Seguridad' (recibido: '$OU')."; exit 1 ;;
esac

# uid sin espacios ni caracteres raros (evita LDIF mal formado e inyección de dn)
if [[ ! "$UID_VAL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: --uid solo admite letras, números, punto, guion y guion bajo."
  exit 1
fi

# --- Entorno -----------------------------------------------------------------
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: no existe $ROOT_DIR/.env."
  echo "Usa el .env académico versionado o copia .env.example y rellena valores reales."
  exit 1
fi
# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "ERROR: el contenedor ${CONTAINER} no está corriendo."
  echo "Arráncalo con:  cd compose && docker compose up -d openldap"
  exit 1
fi

GIVEN="${GIVEN:-$NOMBRE}"
MAIL="${MAIL:-${UID_VAL}@${LDAP_DOMAIN}}"
USER_DN="uid=${UID_VAL},ou=${OU},ou=Usuarios,${LDAP_BASE_DN}"

# --- ¿Ya existe? -------------------------------------------------------------
if docker exec "$CONTAINER" ldapsearch -x -LLL \
      -H ldap://localhost \
      -b "$USER_DN" -s base \
      -D "cn=admin,${LDAP_BASE_DN}" \
      -w "$LDAP_ADMIN_PASSWORD" dn >/dev/null 2>&1; then
  echo "ERROR: ya existe una entrada con dn: ${USER_DN}"
  exit 1
fi

# --- Hash de la contraseña ---------------------------------------------------
echo "==> Generando hash {SSHA} de la contraseña"
HASH="$(docker exec "$CONTAINER" slappasswd -s "$PASSWORD")"
if [[ "$HASH" != \{SSHA\}* ]]; then
  echo "ERROR: slappasswd no devolvió un hash {SSHA} válido."
  exit 1
fi

# --- Aplicar con ldapadd -----------------------------------------------------
echo "==> Creando ${USER_DN}"
docker exec -i "$CONTAINER" ldapadd -x \
  -H ldap://localhost \
  -D "cn=admin,${LDAP_BASE_DN}" \
  -w "$LDAP_ADMIN_PASSWORD" <<LDIF
dn: ${USER_DN}
objectClass: inetOrgPerson
objectClass: organizationalPerson
objectClass: person
objectClass: top
uid: ${UID_VAL}
cn: ${NOMBRE}
sn: ${APELLIDO}
givenName: ${GIVEN}
mail: ${MAIL}
userPassword: ${HASH}
LDIF

# --- Verificar bind del propio usuario --------------------------------------
echo "==> Verificando que el usuario puede hacer bind con su contraseña"
docker exec "$CONTAINER" ldapwhoami -x \
  -H ldap://localhost \
  -D "$USER_DN" \
  -w "$PASSWORD" >/dev/null
echo "OK: bind del usuario correcto."

# --- Semilla opcional en el LDIF de bootstrap --------------------------------
if [[ "$SEED_BOOTSTRAP" == "true" ]]; then
  case "$OU" in
    Desarrollo) LDIF_FILE="$ROOT_DIR/ldap/bootstrap/02-users-desarrollo.ldif" ;;
    Seguridad)  LDIF_FILE="$ROOT_DIR/ldap/bootstrap/03-users-seguridad.ldif" ;;
  esac
  echo "==> Sembrando el usuario en ${LDIF_FILE#"$ROOT_DIR"/} (persistencia)"
  {
    printf '\n'
    printf 'dn: %s\n' "$USER_DN"
    printf 'objectClass: inetOrgPerson\n'
    printf 'objectClass: organizationalPerson\n'
    printf 'objectClass: person\n'
    printf 'objectClass: top\n'
    printf 'uid: %s\n' "$UID_VAL"
    printf 'cn: %s\n' "$NOMBRE"
    printf 'sn: %s\n' "$APELLIDO"
    printf 'givenName: %s\n' "$GIVEN"
    printf 'mail: %s\n' "$MAIL"
    printf 'userPassword: %s\n' "$HASH"
  } >> "$LDIF_FILE"
  echo "OK: agregado al bootstrap. Se recreará al hacer 'docker compose down -v && up'."
fi

echo
echo "Usuario creado: ${USER_DN}"
echo "  mail: ${MAIL}"
echo "Pruébalo en OwnCloud o enrólalo en PrivacyIDEA con su uid: ${UID_VAL}"
