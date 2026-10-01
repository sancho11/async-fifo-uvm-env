# Directorio raiz para los `include de las clases UVM.
# El Makefile convierte estas lineas en opciones -i de xvlog y las filtra del
# filelist generado. Las clases NO se listan como fuentes: se insertan desde el
# fichero de paquete de su agente/env con su ruta relativa a uvmproject/.
+incdir+uvmproject

# ===== RTL (OpenTitan) =====
opentitan/prim_assert.sv
opentitan/prim_cdc_rand_delay.sv
opentitan/prim_flop_2sync.sv
opentitan/prim_flop.sv
opentitan/prim_fifo_async.sv
opentitan/prim_flop_macros.sv
opentitan/prim_util_pkg.sv

# ===== Interfaces =====
# Van compiladas, no incluidas: una interface no puede vivir dentro de package.
uvmproject/if/prim_async_fifo_rd_if.sv
uvmproject/if/prim_async_fifo_wr_if.sv

# ===== Paquetes =====
uvmproject/common/prim_async_fifo_common_pkg.sv
uvmproject/agents/rd/prim_rd_async_fifo_pkg.sv
uvmproject/agents/wr/prim_wr_async_fifo_pkg.sv
uvmproject/env/prim_async_fifo_pkg.sv
uvmproject/tests/prim_async_fifo_test_pkg.sv

# ===== Testbench top =====
uvmproject/tb/testbench.sv
