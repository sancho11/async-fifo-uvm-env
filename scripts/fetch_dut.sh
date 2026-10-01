#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Descarga el RTL del DUT desde OpenTitan.
#
# El diseno bajo prueba no se redistribuye en este repositorio: pertenece al
# proyecto OpenTitan (Apache-2.0) y se obtiene de su origen. El commit esta
# FIJADO a proposito: los resultados de verificacion que documenta la memoria
# se obtuvieron contra esta revision exacta, y apuntar a master haria que el
# banco verificase un diseno distinto del que la memoria describe.
#
# Uso:  scripts/fetch_dut.sh [directorio_destino]     (por defecto: opentitan/)
# -----------------------------------------------------------------------------
set -euo pipefail

OT_SHA="2c36b23a1e0204b20a1d41da7172a0756204b1c8"
OT_RAW="https://raw.githubusercontent.com/lowRISC/opentitan/${OT_SHA}"
DEST="${1:-opentitan}"

# <ruta en el repositorio OpenTitan>  <fichero>
FILES=(
    "hw/ip/prim/rtl                prim_fifo_async.sv"
    "hw/ip/prim/rtl                prim_cdc_rand_delay.sv"
    "hw/ip/prim_generic/rtl        prim_flop_2sync.sv"
    "hw/ip/prim_generic/rtl        prim_flop.sv"
    "hw/ip/prim/rtl                prim_util_pkg.sv"
    "hw/ip/prim/rtl                prim_assert.sv"
    "hw/ip/prim/rtl                prim_flop_macros.sv"
    "hw/ip/prim/rtl                prim_assert_standard_macros.svh"
    "hw/ip/prim/rtl                prim_assert_dummy_macros.svh"
    "hw/ip/prim/rtl                prim_assert_sec_cm.svh"
    "hw/ip/prim/rtl                prim_assert_yosys_macros.svh"
)

command -v curl >/dev/null || { echo "ERROR: curl is required" >&2; exit 1; }
mkdir -p "$DEST"

echo "Fetching DUT sources from OpenTitan @ ${OT_SHA:0:10}"
for entry in "${FILES[@]}"; do
    read -r dir file <<<"$entry"
    if curl -fsS -o "${DEST}/${file}" "${OT_RAW}/${dir}/${file}"; then
        echo "  ok    ${file}"
    else
        echo "  FAIL  ${file}  (${dir})" >&2
        exit 1
    fi
done
echo "Done. ${#FILES[@]} files in ${DEST}/"
