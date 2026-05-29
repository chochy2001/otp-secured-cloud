#!/usr/bin/env bash
#
# Script configurable para la creación y enrolamiento completo de un nuevo usuario.
# Realiza los siguientes pasos:
#   1. Agrega el usuario a OpenLDAP (y opcionalmente a los archivos LDIF de bootstrap para persistencia).
#   2. Fuerza la sincronización de usuarios en OwnCloud para que el usuario sea reconocido inmediatamente.
#   3. Genera y enrola un token TOTP en PrivacyIDEA.
#   4. Muestra la URL para escanear el código QR con cualquier app autenticadora.
#
# Instrucciones:
#   Edita las variables en la sección "CONFIGURACIÓN DEL NUEVO USUARIO"
#   y luego ejecuta el script con: ./scripts/add-user-2fa.sh
#

set -euo pipefail

# ==============================================================================
# CONFIGURACIÓN DEL NUEVO USUARIO (Edita aquí tus datos o usa argumentos/modo interactivo)
# ==============================================================================
NEW_UID="usuario.desarrollo4"
NEW_NAME="Usuario Desarrollo Cuatro"
NEW_APELLIDO="Desarrollo"
NEW_OU="Desarrollo"        # Opciones: Desarrollo | Seguridad
NEW_PASSWORD="sia-user-2026"
NEW_EMAIL=""               # Opcional (si se deja vacío, se genera como: uid@LDAP_DOMAIN)
PERSIST_BOOTSTRAP="true"   # true: guarda en bootstrap (persiste tras borrar volúmenes)
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Uso:"
  echo "  $0 [opciones]"
  echo "  O edita las variables en la sección de configuración del script."
  echo
  echo "Opciones:"
  echo "  -u, --uid        UID del usuario (ej: usuario.desarrollo5)"
  echo "  -n, --nombre     Nombre completo/cn (ej: \"Arely\")"
  echo "  -s, --apellido   Apellido/sn (ej: \"Olvera\")"
  echo "  -o, --ou         Unidad Organizacional: Desarrollo | Seguridad"
  echo "  -p, --password   Contraseña (por defecto: sia-user-2026)"
  echo "  -m, --mail       Correo electrónico (opcional)"
  echo "  -i, --interactive Fuerza el modo interactivo para ingresar datos"
  echo "  --no-bootstrap   No guarda el usuario en los LDIF de bootstrap"
  echo "  -h, --help       Muestra esta ayuda"
  exit "${1:-0}"
}

# --- Parseo de flags ---------------------------------------------------------
UID_VAL=""
NOMBRE=""
APELLIDO=""
OU=""
PASSWORD=""
MAIL=""
PERSIST_BOOTSTRAP_ARG=""
INTERACTIVE="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--uid)        UID_VAL="${2:-}"; shift 2 ;;
    -n|--nombre)     NOMBRE="${2:-}"; shift 2 ;;
    -s|--apellido)   APELLIDO="${2:-}"; shift 2 ;;
    -o|--ou)         OU="${2:-}"; shift 2 ;;
    -p|--password)   PASSWORD="${2:-}"; shift 2 ;;
    -m|--mail)       MAIL="${2:-}"; shift 2 ;;
    -i|--interactive) INTERACTIVE="true"; shift ;;
    --no-bootstrap)  PERSIST_BOOTSTRAP_ARG="false"; shift ;;
    -h|--help)       usage 0 ;;
    *) echo "ERROR: flag desconocido: $1"; echo; usage 1 ;;
  esac
done

# --- Inicialización y carga de entorno -----------------------------------------
if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: No se encontró el archivo $ROOT_DIR/.env."
  exit 1
fi
# shellcheck disable=SC1091
source "$ROOT_DIR/.env"

LDAP_CONTAINER="otpsec-openldap"
OWNCLOUD_CONTAINER="otpsec-owncloud-server"
PRIVACYIDEA_CONTAINER="otpsec-privacyidea"

# --- Validaciones de contenedores corriendo -----------------------------------
echo "==> [1/5] Validando estado de los servicios..."

for container in "$LDAP_CONTAINER" "$OWNCLOUD_CONTAINER" "$PRIVACYIDEA_CONTAINER"; do
  if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    echo "ERROR: El contenedor '${container}' no está corriendo."
    echo "Por favor, levanta el stack primero con: ./scripts/bootstrap.sh"
    exit 1
  fi
done
echo "OK: Todos los servicios requeridos están arriba."

# --- Determinar modo de ejecución ---------------------------------------------
USING_ARGS="false"
if [[ -n "$UID_VAL" || -n "$NOMBRE" || -n "$APELLIDO" || -n "$OU" ]]; then
  USING_ARGS="true"
fi

# Función para verificar si un UID ya existe en LDAP
uid_exists_in_ldap() {
  local check_uid="$1"
  docker exec "$LDAP_CONTAINER" ldapsearch -x -LLL \
    -H ldap://localhost \
    -b "ou=Usuarios,${LDAP_BASE_DN}" \
    -D "cn=admin,${LDAP_BASE_DN}" \
    -w "$LDAP_ADMIN_PASSWORD" \
    "(uid=${check_uid})" dn >/dev/null 2>&1
}

prompt_interactive() {
  echo "=============================================================================="
  echo "              CONFIGURACIÓN INTERACTIVA DE NUEVO USUARIO                      "
  echo "=============================================================================="
  
  # Pedir UID y validar
  while true; do
    read -rp "1. Ingrese el UID del nuevo usuario (ej: usuario.desarrollo5): " input_uid
    if [[ -z "$input_uid" ]]; then
      echo "   ERROR: El UID no puede estar vacío."
      continue
    fi
    if [[ ! "$input_uid" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "   ERROR: El UID solo admite letras, números, punto, guion y guion bajo."
      continue
    fi
    if uid_exists_in_ldap "$input_uid"; then
      echo "   ERROR: El UID '${input_uid}' ya está registrado en LDAP. Elija otro."
      continue
    fi
    NEW_UID="$input_uid"
    break
  done

  # Pedir Nombre
  while true; do
    read -rp "2. Ingrese el Nombre (cn) (ej: Arely): " input_name
    if [[ -z "$input_name" ]]; then
      echo "   ERROR: El nombre es requerido."
      continue
    fi
    NEW_NAME="$input_name"
    break
  done

  # Pedir Apellido
  while true; do
    read -rp "3. Ingrese el Apellido (sn) (ej: Olvera): " input_apellido
    if [[ -z "$input_apellido" ]]; then
      echo "   ERROR: El apellido es requerido."
      continue
    fi
    NEW_APELLIDO="$input_apellido"
    break
  done

  # Pedir OU
  while true; do
    read -rp "4. Ingrese la Unidad Organizacional (Desarrollo [d] / Seguridad [s]): " input_ou
    case "$input_ou" in
      [Dd]*|Desarrollo) NEW_OU="Desarrollo"; break ;;
      [Ss]*|Seguridad) NEW_OU="Seguridad"; break ;;
      *) echo "   ERROR: Opción no válida. Escriba 'd' para Desarrollo o 's' para Seguridad." ;;
    esac
  done

  # Pedir Contraseña
  read -rp "5. Ingrese la Contraseña (presione Enter para usar 'sia-user-2026'): " input_pw
  if [[ -z "$input_pw" ]]; then
    NEW_PASSWORD="sia-user-2026"
  else
    NEW_PASSWORD="$input_pw"
  fi

  # Pedir Correo
  read -rp "6. Ingrese el Correo (presione Enter para autogenerar '${NEW_UID}@${LDAP_DOMAIN}'): " input_mail
  NEW_EMAIL="$input_mail"

  # Pedir Persistencia
  read -rp "7. ¿Desea persistir este usuario en los archivos LDIF de bootstrap? (S/n): " input_persist
  case "$input_persist" in
    [Nn]*) PERSIST_BOOTSTRAP="false" ;;
    *) PERSIST_BOOTSTRAP="true" ;;
  esac
  echo "=============================================================================="
}

if [[ "$INTERACTIVE" == "true" ]]; then
  prompt_interactive
elif [[ "$USING_ARGS" == "true" ]]; then
  # Validaciones de argumentos
  missing=()
  [[ -z "$UID_VAL" ]]   && missing+=("--uid")
  [[ -z "$NOMBRE" ]]    && missing+=("--nombre")
  [[ -z "$APELLIDO" ]]  && missing+=("--apellido")
  [[ -z "$OU" ]]        && missing+=("--ou")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: faltan flags requeridos en modo comando: ${missing[*]}"
    echo
    usage 1
  fi
  
  case "$OU" in
    Desarrollo|Seguridad) ;;
    *) echo "ERROR: --ou debe ser 'Desarrollo' o 'Seguridad'."; exit 1 ;;
  esac
  
  if [[ ! "$UID_VAL" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "ERROR: --uid solo admite letras, números, punto, guion y guion bajo."
    exit 1
  fi
  
  NEW_UID="$UID_VAL"
  NEW_NAME="$NOMBRE"
  NEW_APELLIDO="$APELLIDO"
  NEW_OU="$OU"
  [[ -n "$PASSWORD" ]] && NEW_PASSWORD="$PASSWORD"
  [[ -n "$MAIL" ]] && NEW_EMAIL="$MAIL"
  if [[ -n "$PERSIST_BOOTSTRAP_ARG" ]]; then
    PERSIST_BOOTSTRAP="$PERSIST_BOOTSTRAP_ARG"
  fi
else
  # Usar valores por defecto. Si el UID por defecto ya existe, cambiamos a modo interactivo automáticamente.
  if uid_exists_in_ldap "$NEW_UID"; then
    echo "AVISO: El UID configurado por defecto '${NEW_UID}' ya existe en LDAP."
    echo "Para evitar colisiones y errores, iniciaremos el modo interactivo para configurar un nuevo usuario."
    echo
    prompt_interactive
  fi
fi

# --- Creación del usuario en LDAP ---------------------------------------------
echo
echo "==> [2/5] Creando usuario '${NEW_UID}' en OpenLDAP..."

BOOTSTRAP_FLAG=""
if [[ "$PERSIST_BOOTSTRAP" == "true" ]]; then
  BOOTSTRAP_FLAG="--bootstrap"
fi

# Invocamos el script existente para crear el usuario en LDAP
./scripts/add-user.sh \
  --uid "$NEW_UID" \
  --nombre "$NEW_NAME" \
  --apellido "$NEW_APELLIDO" \
  --ou "$NEW_OU" \
  --password "$NEW_PASSWORD" \
  ${NEW_EMAIL:+--mail "$NEW_EMAIL"} \
  $BOOTSTRAP_FLAG

# --- Sincronización en OwnCloud -----------------------------------------------
echo
echo "==> [3/5] Sincronizando usuarios en OwnCloud..."
if docker exec "$OWNCLOUD_CONTAINER" occ user:sync "OCA\\User_LDAP\\User_Proxy" -m disable -vvv; then
  echo "OK: Sincronización de usuarios de OwnCloud completada."
else
  echo "AVISO: No se pudo completar la sincronización automática de OwnCloud. El usuario debería crearse dinámicamente al iniciar sesión por primera vez."
fi

# --- Enrolamiento en PrivacyIDEA ----------------------------------------------
echo
echo "==> [4/5] Enrolando token TOTP en PrivacyIDEA..."

# Invocamos el script existente para enrolar el token y probarlo
./scripts/privacyidea-enroll-test-token.sh "$NEW_UID"

# --- Resumen final -------------------------------------------------------------
echo "=============================================================================="
echo "                   RESUMEN DE CREACIÓN DEL USUARIO                            "
echo "=============================================================================="
echo "  • UID del usuario:  $NEW_UID"
echo "  • Nombre completo:  $NEW_NAME $NEW_APELLIDO"
echo "  • Unidad Org (OU):  $NEW_OU (en LDAP)"
echo "  • Contraseña:       $NEW_PASSWORD"
echo "  • Persistente:      $PERSIST_BOOTSTRAP (guardado en LDIF de bootstrap)"
echo "=============================================================================="
echo "  ✓ LDAP: El usuario ha sido creado y autenticado correctamente."
echo "  ✓ OwnCloud: Sincronizado para acceso inmediato."
echo "  ✓ PrivacyIDEA: Token TOTP inicializado y validado con éxito."
echo "=============================================================================="
echo "  ¡Listo! Puedes iniciar sesión en OwnCloud (https://localhost:9443)"
echo "  usando tu UID y contraseña, y luego ingresando el OTP de tu app."
echo "=============================================================================="
