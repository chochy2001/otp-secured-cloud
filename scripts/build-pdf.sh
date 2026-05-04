#!/usr/bin/env bash
#
# Ensambla la memoria técnica final en un único PDF a partir de los
# archivos Markdown del directorio docs/.
#
# Requisitos: pandoc y una distribución TeX con XeLaTeX o LuaLaTeX.
#   En macOS: brew install pandoc basictex (mactex completo si falla)
#   En Debian/Ubuntu: sudo apt install pandoc texlive-xetex
#
# Salida: build/entregable-otp-secured-cloud.pdf

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/build"
OUTPUT_FILE="${OUTPUT_DIR}/entregable-otp-secured-cloud.pdf"

mkdir -p "${OUTPUT_DIR}"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "ERROR: pandoc no está instalado. Ver requisitos arriba."
  exit 1
fi

# Orden del entregable. Si se cambia, mantener consistencia con docs/indice.md.
DOC_ORDER=(
  "${ROOT_DIR}/docs/portada.md"
  "${ROOT_DIR}/docs/introduccion.md"
  "${ROOT_DIR}/docs/conceptos-basicos.md"
  "${ROOT_DIR}/docs/arbol-ldap.md"
  "${ROOT_DIR}/docs/arquitectura.md"
  "${ROOT_DIR}/docs/memoria-tecnica.md"
  "${ROOT_DIR}/docs/auditoria.md"
  "${ROOT_DIR}/docs/conclusiones.md"
  "${ROOT_DIR}/docs/glosario.md"
  "${ROOT_DIR}/docs/bibliografia.md"
  "${ROOT_DIR}/docs/indice-figuras.md"
)

for doc in "${DOC_ORDER[@]}"; do
  if [[ ! -f "${doc}" ]]; then
    echo "ERROR: falta el archivo ${doc}"
    exit 1
  fi
done

PDF_ENGINE="${PDF_ENGINE:-}"
if [[ -z "${PDF_ENGINE}" ]]; then
  if command -v xelatex >/dev/null 2>&1; then
    PDF_ENGINE=xelatex
  elif command -v lualatex >/dev/null 2>&1; then
    PDF_ENGINE=lualatex
  elif command -v pdflatex >/dev/null 2>&1; then
    PDF_ENGINE=pdflatex
  else
    echo "ERROR: no se encontró un motor LaTeX. Instala texlive-xetex (Linux) o basictex/mactex (macOS)."
    exit 1
  fi
fi

echo "==> Ensamblando ${OUTPUT_FILE}"
echo "    Motor: ${PDF_ENGINE}"

pandoc "${DOC_ORDER[@]}" \
  --pdf-engine="${PDF_ENGINE}" \
  --toc \
  --toc-depth=3 \
  -V documentclass=article \
  -V geometry:margin=2.5cm \
  -V fontsize=11pt \
  -V mainfont="Latin Modern Roman" \
  -V monofont="Latin Modern Mono" \
  -V lang=es \
  -V title="Servicio de almacenamiento con autenticación 2FA por OTP" \
  -V subtitle="Proyecto final de Seguridad Informática Avanzada" \
  -V author="Equipo SIA 2026-2 - Facultad de Ingeniería UNAM" \
  -V date="29 de mayo de 2026" \
  -o "${OUTPUT_FILE}"

echo
echo "PDF generado en ${OUTPUT_FILE}"
echo "Tamaño: $(du -h "${OUTPUT_FILE}" | cut -f1)"
