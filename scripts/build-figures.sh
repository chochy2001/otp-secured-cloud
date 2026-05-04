#!/usr/bin/env bash
#
# Renderiza los diagramas Mermaid embebidos en docs/arquitectura.md a
# imágenes PNG en docs/figuras/, listas para incluirse en el PDF del
# entregable.
#
# Requisitos:
#   - mermaid-cli (mmdc): npm install -g @mermaid-js/mermaid-cli
#
# Uso:
#   ./scripts/build-figures.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="${ROOT_DIR}/docs/arquitectura.md"
OUT_DIR="${ROOT_DIR}/docs/figuras"

if ! command -v mmdc >/dev/null 2>&1; then
  echo "ERROR: mmdc no está instalado."
  echo "Instala con: npm install -g @mermaid-js/mermaid-cli"
  exit 1
fi

mkdir -p "${OUT_DIR}"

# Extrae los bloques mermaid del archivo y les asigna un número en
# orden de aparición. Para mantener consistencia con docs/indice-figuras.md
# y docs/figuras/README.md, esperamos exactamente 3 bloques mermaid
# correspondientes a las figuras 1, 3 y 4.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

python3 - "${SOURCE_FILE}" "${TMP_DIR}" <<'PYEOF'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
tmp_dir = Path(sys.argv[2])
pattern = re.compile(r'```mermaid\n(.*?)```', re.DOTALL)
blocks = pattern.findall(source)
if len(blocks) < 1:
    print("AVISO: no se encontraron bloques mermaid en el archivo.")
    raise SystemExit(0)
for i, block in enumerate(blocks, start=1):
    out = tmp_dir / f"block-{i}.mmd"
    out.write_text(block)
print(f"Encontrados {len(blocks)} bloques mermaid.")
PYEOF

# Mapeo bloque-numero a figura-numero. Si en arquitectura.md se reordenan
# los bloques o se agregan nuevos, ajustar aquí.
declare -A BLOCK_TO_FIGURE=(
  [1]=1
  [2]=3
  [3]=4
)

for block_num in "${!BLOCK_TO_FIGURE[@]}"; do
  fig_num="${BLOCK_TO_FIGURE[$block_num]}"
  src="${TMP_DIR}/block-${block_num}.mmd"
  dst="${OUT_DIR}/figura${fig_num}.png"
  if [[ ! -f "${src}" ]]; then
    echo "AVISO: bloque ${block_num} no encontrado, se omite figura ${fig_num}."
    continue
  fi
  echo "==> Renderizando figura${fig_num}.png"
  mmdc -i "${src}" -o "${dst}" -t default -b white --quiet
done

echo
echo "Figuras generadas en ${OUT_DIR}:"
ls -la "${OUT_DIR}"
