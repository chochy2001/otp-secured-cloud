#!/usr/bin/env bash
#
# Genera el documento unificado del entregable concatenando el
# prefacio narrativo + los 10 archivos del entregable definidos en
# docs/indice.md. Luego invoca scripts/build-pdf.sh con la variable
# de entorno ENTREGABLE_MD para producir el PDF, HTML y DOCX a
# partir del .md unificado.
#
# El archivo docs/entregable-final.md se REGENERA siempre. No editar
# a mano: cambios al contenido se hacen en los archivos fuente
# (prefacio.md y los 10 del entregable).
#
# Salida:
#   docs/entregable-final.md
#   build/entregable-otp-secured-cloud.{pdf,html,docx}

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_MD="${ROOT_DIR}/docs/entregable-final.md"

# Orden definitivo: portada e indice primero, luego prefacio narrativo,
# luego los 9 archivos restantes del cuerpo en el orden del indice.
ORDER=(
  "${ROOT_DIR}/docs/portada.md"
  "${ROOT_DIR}/docs/indice.md"
  "${ROOT_DIR}/docs/prefacio.md"
  "${ROOT_DIR}/docs/introduccion.md"
  "${ROOT_DIR}/docs/conceptos-basicos.md"
  "${ROOT_DIR}/docs/arbol-ldap.md"
  "${ROOT_DIR}/docs/arquitectura.md"
  "${ROOT_DIR}/docs/memoria-tecnica.md"
  "${ROOT_DIR}/docs/conclusiones.md"
  "${ROOT_DIR}/docs/glosario.md"
  "${ROOT_DIR}/docs/bibliografia.md"
  "${ROOT_DIR}/docs/indice-figuras.md"
)

# Validar que todos los archivos fuente existan antes de concatenar.
for f in "${ORDER[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: falta archivo fuente ${f}"
    exit 1
  fi
done

echo "==> Concatenando ${#ORDER[@]} archivos en ${OUT_MD}"

# Concatenar con separador de pagina. \newpage es directiva LaTeX que
# pandoc traduce a salto de pagina real en PDF. Queda literal en HTML
# y DOCX pero el lector objetivo es el PDF.
{
  for i in "${!ORDER[@]}"; do
    cat "${ORDER[$i]}"
    if [[ $i -lt $((${#ORDER[@]} - 1)) ]]; then
      printf '\n\n\\newpage\n\n'
    fi
  done
} > "${OUT_MD}"

LINEAS=$(wc -l < "${OUT_MD}")
PALABRAS=$(wc -w < "${OUT_MD}")
echo "    OK lineas=${LINEAS} palabras=${PALABRAS}"

# Verificar ausencia de caracteres prohibidos en el documento generado.
echo "==> Verificando ausencia de caracteres prohibidos"
if grep -nE '(—|→|✓|✗|🔒|🛡|🔑|💡|⚠️|📋|🚀|💻|📌)' "${OUT_MD}" >/dev/null 2>&1; then
  echo "ERROR: caracteres prohibidos en ${OUT_MD}:"
  grep -nE '(—|→|✓|✗|🔒|🛡|🔑|💡|⚠️|📋|🚀|💻|📌)' "${OUT_MD}"
  exit 1
fi
echo "    OK sin caracteres prohibidos"

# Invocar build-pdf.sh apuntando al .md unificado.
echo "==> Invocando build-pdf.sh con ENTREGABLE_MD=${OUT_MD}"
ENTREGABLE_MD="${OUT_MD}" "${ROOT_DIR}/scripts/build-pdf.sh"

echo
echo "Listo. Artefactos en ${ROOT_DIR}/build/"
