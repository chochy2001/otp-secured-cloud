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

# Orden del entregable. Mantener consistencia con docs/indice.md.
# Si la variable de entorno ENTREGABLE_MD esta definida, usa ese archivo
# unico (modo "documento unificado"). Si no, usa el comportamiento
# historico de concatenar 10 archivos. El segundo modo se preserva
# para no romper invocaciones existentes.
# Nota: docs/auditoria.md no se incluye porque el profesor confirmo que la
# capa de auditoria no se evalua, y los logs JSON crudos generan paginas
# extensas con lineas largas. La memoria tecnica ya describe el flujo y
# referencia el archivo para quien quiera profundizar.
if [[ -n "${ENTREGABLE_MD:-}" ]]; then
  if [[ ! -f "${ENTREGABLE_MD}" ]]; then
    echo "ERROR: ENTREGABLE_MD=${ENTREGABLE_MD} no existe."
    exit 1
  fi
  DOC_ORDER=( "${ENTREGABLE_MD}" )
  echo "Modo: documento unico (ENTREGABLE_MD=${ENTREGABLE_MD})"
else
  DOC_ORDER=(
    "${ROOT_DIR}/docs/portada.md"
    "${ROOT_DIR}/docs/indice.md"
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
  echo "Modo: concatenacion historica de 10 archivos"
fi

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
# Las figuras se copian a una subcarpeta del TMP para usar rutas
# relativas en las referencias (tectonic emite un warning cuando ve
# rutas absolutas a recursos por reproducibilidad entre máquinas).
TMP_DOCS_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DOCS_DIR}"' EXIT

mkdir -p "${TMP_DOCS_DIR}/figuras"
for n in 1 2 3 4 5 6; do
  src_png="${ROOT_DIR}/docs/figuras/figura${n}.png"
  if [[ -f "${src_png}" ]]; then
    cp "${src_png}" "${TMP_DOCS_DIR}/figuras/figura${n}.png"
  fi
done

PROCESSED_DOCS=()
for doc in "${DOC_ORDER[@]}"; do
  base="$(basename "${doc}")"
  out="${TMP_DOCS_DIR}/${base}"
  python3 - "${doc}" "${out}" "${TMP_DOCS_DIR}/figuras" <<'PYEOF'
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
    # Referencia relativa: el .md preprocesado y la carpeta figuras
    # viven en el mismo TMP_DOCS_DIR, así pandoc resuelve la ruta sin
    # apuntar a /private/var/folders/... y tectonic no avisa por
    # rutas absolutas no reproducibles.
    result.append(f"![](figuras/figura{fig_num}.png)\\ \n")
    last_end = block_match.end()
result.append(src[last_end:])
dst.write_text("".join(result))
PYEOF
  PROCESSED_DOCS+=("${out}")
done

# Sin --toc ni --metadata title/author: la portada y el índice ya viven
# como Markdown propios al inicio del orden de documentos. Pandoc en
# modo article sin title/author no inserta su propia cubierta, así
# docs/portada.md aparece como primera página tal cual la diseñamos.
# --resource-path=TMP_DOCS_DIR es necesario para que pandoc resuelva
# las referencias relativas 'figuras/figuraN.png' contra la copia
# de las imágenes que se hizo en ese directorio.
PANDOC_COMMON=(
  -V documentclass=article
  -V geometry:margin=2.5cm
  -V fontsize=11pt
  -V lang=es
  --resource-path="${TMP_DOCS_DIR}"
)

# Variables específicas del PDF: mitigar líneas largas (URLs en
# bibliografía, DN de LDAP en código) que en LaTeX producen avisos
# 'Overfull \hbox'. \sloppy relaja el ajuste y xurl rompe URLs.
PDF_HEADER_FILE="${TMP_DOCS_DIR}/header.tex"
cat > "${PDF_HEADER_FILE}" <<'TEXEOF'
\usepackage{xurl}
\sloppy
% emergencystretch deja que LaTeX estire una línea hasta este valor
% antes de generar un Overfull \hbox. 3em es lo bastante para
% absorber URLs y DNs largos en bibliografía y código sin que el
% texto pierda legibilidad.
\setlength{\emergencystretch}{3em}
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
  # Nota sobre warnings: tectonic emite avisos 'absolute path ... build
  # may not be reproducible' por cada figura. Esto pasa porque pandoc
  # copia internamente las imágenes a su propio media-temp y pasa la
  # ruta absoluta a LaTeX. No afecta el PDF resultante; las imágenes
  # se embeben correctamente. Es ruido informativo de tectonic, no un
  # error de configuración.
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
