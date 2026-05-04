#!/usr/bin/env bash
#
# Ensambla la memoria técnica final del proyecto a partir de los
# archivos Markdown del directorio docs/. Por defecto produce un PDF
# con pandoc + un motor LaTeX. Si LaTeX no está instalado, cae a
# HTML y DOCX como salidas equivalentes que cualquier evaluador puede
# abrir sin problema.
#
# Requisitos:
#   - pandoc (siempre): brew install pandoc | sudo apt install pandoc
#   - Motor LaTeX (para PDF):
#       macOS recomendado: brew install tectonic (no requiere sudo)
#       Linux:             sudo apt install texlive-xetex
#       Alternativa macOS: brew install --cask basictex (pide sudo)
#
# Salida:
#   build/entregable-otp-secured-cloud.pdf  (si hay LaTeX)
#   build/entregable-otp-secured-cloud.html (siempre)
#   build/entregable-otp-secured-cloud.docx (siempre)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/build"
PDF_FILE="${OUTPUT_DIR}/entregable-otp-secured-cloud.pdf"
HTML_FILE="${OUTPUT_DIR}/entregable-otp-secured-cloud.html"
DOCX_FILE="${OUTPUT_DIR}/entregable-otp-secured-cloud.docx"

mkdir -p "${OUTPUT_DIR}"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "ERROR: pandoc no está instalado."
  echo "macOS:  brew install pandoc"
  echo "Linux:  sudo apt install pandoc"
  exit 1
fi

# Orden del entregable. Si se cambia, mantener consistencia con docs/indice.md.
# Nota: docs/auditoria.md no se incluye porque el profesor confirmó que la
# capa de auditoría no se evalúa, y los logs JSON crudos generan páginas
# extensas con líneas largas. La memoria técnica ya describe el flujo y
# referencia el archivo para quien quiera profundizar.
DOC_ORDER=(
  "${ROOT_DIR}/docs/portada.md"
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

for doc in "${DOC_ORDER[@]}"; do
  if [[ ! -f "${doc}" ]]; then
    echo "ERROR: falta el archivo ${doc}"
    exit 1
  fi
done

# Recordar al equipo si las figuras PNG no existen.
MISSING_FIGS=0
for n in 1 2 3 4 5 6; do
  if [[ ! -f "${ROOT_DIR}/docs/figuras/figura${n}.png" ]]; then
    MISSING_FIGS=$((MISSING_FIGS + 1))
  fi
done
if [[ "${MISSING_FIGS}" -gt 0 ]]; then
  echo "AVISO: faltan ${MISSING_FIGS} figura(s) PNG en docs/figuras/."
  echo "       Genéralas con './scripts/build-figures.sh' antes para incluirlas como imágenes."
  echo "       Si no se generan, los bloques mermaid se incluyen como código fuente."
fi

# Recordar al equipo si el nombre del profesor sigue sin rellenarse
# en la portada. La línea se reconoce por contener guiones bajos.
if grep -q '^\*\*Profesor:\*\* _\+' "${ROOT_DIR}/docs/portada.md"; then
  echo "AVISO: el nombre del profesor en docs/portada.md sigue como línea en blanco."
  echo "       Edita el archivo y reemplaza los guiones bajos por el nombre antes de entregar."
fi

# Preprocesar los Markdown: si la PNG existe, reemplazar el bloque
# mermaid que sigue al encabezado '### Figura N:' por una referencia
# de imagen para que pandoc inserte la PNG en el PDF y DOCX. Los
# archivos originales no se tocan; trabajamos sobre copias en TMP.
TMP_DOCS_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DOCS_DIR}"' EXIT

PROCESSED_DOCS=()
for doc in "${DOC_ORDER[@]}"; do
  base="$(basename "${doc}")"
  out="${TMP_DOCS_DIR}/${base}"
  python3 - "${doc}" "${out}" "${ROOT_DIR}/docs/figuras" <<'PYEOF'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1]).read_text()
dst = Path(sys.argv[2])
fig_dir = Path(sys.argv[3])

heading_re = re.compile(r"^(###\s+Figura\s+(\d+)\s*:[^\n]*)\n", re.MULTILINE)
block_re = re.compile(r"```mermaid\n.*?```", re.DOTALL)

result = []
last_end = 0
for heading_match in heading_re.finditer(src):
    fig_num = int(heading_match.group(2))
    png = fig_dir / f"figura{fig_num}.png"
    if not png.exists():
        continue
    block_match = block_re.search(src, heading_match.end())
    if not block_match:
        continue
    # Insertar la imagen con alt-text vacío para que pandoc no genere
    # un caption automático ("Figura N:") que se duplicaría con el
    # encabezado "### Figura N:" que ya está arriba.
    # `\ ` (espacio escapado) en la línea posterior evita que pandoc
    # convierta la imagen en una figura LaTeX numerada.
    result.append(src[last_end:block_match.start()])
    result.append(f"![]({png.as_posix()})\\ \n")
    last_end = block_match.end()
result.append(src[last_end:])
dst.write_text("".join(result))
PYEOF
  PROCESSED_DOCS+=("${out}")
done

PANDOC_COMMON=(
  --toc
  --toc-depth=3
  -V documentclass=article
  -V geometry:margin=2.5cm
  -V fontsize=11pt
  -V lang=es
  --metadata title="Servicio de almacenamiento con autenticación 2FA por OTP"
  --metadata subtitle="Proyecto final de Seguridad Informática Avanzada"
  --metadata author="Equipo SIA 2026-2, Facultad de Ingeniería UNAM"
  --metadata date="29 de mayo de 2026"
)

# Variables específicas del PDF: mitigar líneas largas (URLs en
# bibliografía, DN de LDAP en código) que en LaTeX producen avisos
# 'Overfull \hbox'. \sloppy relaja el ajuste y xurl rompe URLs.
PDF_HEADER_FILE="${TMP_DOCS_DIR}/header.tex"
cat > "${PDF_HEADER_FILE}" <<'TEXEOF'
\usepackage{xurl}
\sloppy
TEXEOF

# HTML (siempre se genera, no requiere LaTeX)
echo "==> Generando ${HTML_FILE}"
pandoc "${PROCESSED_DOCS[@]}" \
  "${PANDOC_COMMON[@]}" \
  --standalone \
  --embed-resources \
  -o "${HTML_FILE}"
echo "    OK ($(du -h "${HTML_FILE}" | cut -f1))"

# DOCX (siempre se genera, útil si se abre en Word)
echo "==> Generando ${DOCX_FILE}"
pandoc "${PROCESSED_DOCS[@]}" \
  "${PANDOC_COMMON[@]}" \
  -o "${DOCX_FILE}"
echo "    OK ($(du -h "${DOCX_FILE}" | cut -f1))"

# PDF (solo si hay un motor LaTeX disponible)
PDF_ENGINE="${PDF_ENGINE:-}"
if [[ -z "${PDF_ENGINE}" ]]; then
  for engine in xelatex lualatex pdflatex tectonic; do
    if command -v "${engine}" >/dev/null 2>&1; then
      PDF_ENGINE="${engine}"
      break
    fi
  done
fi

if [[ -n "${PDF_ENGINE}" ]]; then
  echo "==> Generando ${PDF_FILE} con ${PDF_ENGINE}"
  if pandoc "${PROCESSED_DOCS[@]}" \
    "${PANDOC_COMMON[@]}" \
    --pdf-engine="${PDF_ENGINE}" \
    -H "${PDF_HEADER_FILE}" \
    -o "${PDF_FILE}"; then
    echo "    OK ($(du -h "${PDF_FILE}" | cut -f1))"
  else
    echo "AVISO: pandoc falló al ensamblar el PDF (probablemente faltan paquetes LaTeX)."
    echo "       Con tectonic, los paquetes se descargan al primer uso; reintentar suele funcionar."
    echo "       Con basictex/texlive, ejecuta 'sudo tlmgr install <paquete>' según el error."
    echo "       El HTML y el DOCX ya quedaron disponibles arriba."
  fi
else
  echo "AVISO: no se encontró un motor LaTeX (xelatex, lualatex, pdflatex, tectonic)."
  echo "       PDF omitido. Para producirlo:"
  echo "         macOS recomendado: brew install tectonic (sin sudo)"
  echo "         Linux:             sudo apt install texlive-xetex"
  echo "       El HTML y el DOCX están listos en ${OUTPUT_DIR}/."
fi

echo
echo "Artefactos en ${OUTPUT_DIR}:"
ls -la "${OUTPUT_DIR}"
