#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Genera un DUT MUTADO cuyo puntero cruza en binario en vez de en codigo Gray:
# el defecto CDC de libro. Sirve para medir si el banco lo detecta.
#
# El resultado NO se versiona. Es RTL de terceros modificado, y conservarlo en
# el arbol invitaria a confundirlo con el diseno real; el procedimiento cabe en
# este guion, de modo que la reproducibilidad no exige guardarlo.
#
# Uso:  scripts/make_mutant.sh && make run FILELIST=filelist_mutant.f TEST=...
# -----------------------------------------------------------------------------
set -euo pipefail

SRC="${1:-opentitan}"
DEST="${2:-mutant_gray}"
FL="${3:-filelist_mutant.f}"

[ -d "$SRC" ] || { echo "ERROR: no existe $SRC. Ejecuta antes scripts/fetch_dut.sh" >&2; exit 1; }

rm -rf "$DEST"; mkdir -p "$DEST"
cp "$SRC"/*.sv "$SRC"/*.svh "$DEST"/

python3 - "$DEST" <<'PY'
import io, sys
p = f"{sys.argv[1]}/prim_fifo_async.sv"
s = io.open(p, encoding="utf-8").read()

viejo_enc = """      // Perform the XOR conversion
      dec2gray = decval_in;
      dec2gray ^= (decval_in >> 1);

      // Override the MSB
      dec2gray[PTR_WIDTH-1] = decval[PTR_WIDTH-1];"""
assert s.count(viejo_enc) == 1, "no se encontro dec2gray; revisa la revision del RTL"
s = s.replace(viejo_enc, "      // MUTACION: sin conversion Gray, el puntero cruza en binario.\n      dec2gray = decval;")

viejo_dec = """      dec_tmp = '0;
      for (int unsigned i = PTR_WIDTH-1; i > 0; i--) begin
        dec_tmp[i-1] = dec_tmp[i] ^ grayval[i-1];
      end
      dec_tmp_sub = (PTR_WIDTH)'(Depth) - dec_tmp - 1'b1;
      if (grayval[PTR_WIDTH-1]) begin
        gray2dec = dec_tmp_sub;
        // Override MSB
        gray2dec[PTR_WIDTH-1] = 1'b1;
        unused_decsub_msb = dec_tmp_sub[PTR_WIDTH-1];
      end else begin
        gray2dec = dec_tmp;
      end"""
assert s.count(viejo_dec) == 1, "no se encontro gray2dec; revisa la revision del RTL"
s = s.replace(viejo_dec, "      // MUTACION: identidad, el puntero ya viaja en binario.\n      dec_tmp = '0; dec_tmp_sub = '0; unused_decsub_msb = 1'b0;\n      gray2dec = grayval;")

io.open(p, "w", encoding="utf-8").write(s)
PY

sed "s|^${SRC}/|${DEST}/|" filelist.f > "$FL"
echo "DUT mutado en ${DEST}/ y filelist en ${FL}"
echo "Se espera que dispare GrayWptr_A y GrayRptr_A, las aserciones del propio DUT."
