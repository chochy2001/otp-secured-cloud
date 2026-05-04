#!/usr/bin/env bash
#
# Renderiza los diagramas Mermaid embebidos en los archivos de docs/
# a imágenes PNG en docs/figuras/, listas para incluirse en el PDF
# del entregable.
#
# Las figuras esperan numeración 1 a 6 según docs/indice-figuras.md.
# Cada bloque mermaid debe ir precedido en el archivo fuente por un
# encabezado en formato exacto:
#
#     ### Figura N: <titulo>
#
# El script detecta ese encabezado y asigna el número N al bloque
# que sigue.
#
# Requisitos:
#   - mermaid-cli (mmdc): npm install -g @mermaid-js/mermaid-cli
#
# Uso:
#   ./scripts/build-figures.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/docs/figuras"

SOURCES=(
  "${ROOT_DIR}/docs/arquitectura.md"
  "${ROOT_DIR}/docs/arbol-ldap.md"
  "${ROOT_DIR}/docs/memoria-tecnica.md"
)

if ! command -v mmdc >/dev/null 2>&1; then
  echo "ERROR: mmdc no está instalado."
  echo "Instala con: npm install -g @mermaid-js/mermaid-cli"
  exit 1
fi

mkdir -p "${OUT_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Extrae cada bloque mermaid junto con el numero de figura asignado por
# el encabezado "### Figura N:" que lo precede. Genera archivos
# block-N.mmd en el directorio temporal.
python3 - "${TMP_DIR}" "${SOURCES[@]}" <<'PYEOF'
import re
import sys
from pathlib import Path

tmp_dir = Path(sys.argv[1])
sources = [Path(p) for p in sys.argv[2:]]

heading_re = re.compile(r'^###\s+Figura\s+(\d+)\s*:', re.MULTILINE)
block_re = re.compile(r'```mermaid\n(.*?)```', re.DOTALL)

found = {}
for source in sources:
    if not source.exists():
        print(f"AVISO: {source} no existe, se omite.")
        continue
    text = source.read_text()
    headings = list(heading_re.finditer(text))
    blocks = list(block_re.finditer(text))
    for heading in headings:
        figure_num = int(heading.group(1))
        candidate = next((b for b in blocks if b.start() > heading.start()), None)
        if candidate is None:
            print(f"AVISO: no hay bloque mermaid despues de figura {figure_num} en {source}.")
            continue
        if figure_num in found:
            print(f"AVISO: figura {figure_num} duplicada (segunda en {source}).")
            continue
        found[figure_num] = candidate.group(1)
        out = tmp_dir / f"block-{figure_num}.mmd"
        out.write_text(candidate.group(1))

if not found:
    print("AVISO: no se encontró ninguna figura mermaid en los archivos fuente.")
    raise SystemExit(0)

print("Figuras detectadas:", ", ".join(str(n) for n in sorted(found)))
PYEOF

# Renderizar cada bloque encontrado.
shopt -s nullglob
for src in "${TMP_DIR}"/block-*.mmd; do
  name="$(basename "${src}" .mmd)"
  fig_num="${name#block-}"
  dst="${OUT_DIR}/figura${fig_num}.png"
  echo "==> Renderizando figura${fig_num}.png"
  mmdc -i "${src}" -o "${dst}" -t default -b white --quiet
done

echo
echo "Figuras generadas en ${OUT_DIR}:"
ls -la "${OUT_DIR}"
