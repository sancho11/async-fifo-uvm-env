`ifndef PRIM_ASYNC_FIFO_DEFINES_SVH
    `define PRIM_ASYNC_FIFO_DEFINES_SVH

    // Configuracion geometrica del DUT, compartida por el paquete comun y por
    // el testbench top. Vive en una cabecera propia porque los paquetes se
    // compilan ANTES que testbench.sv: si los `define solo estuvieran alli, no
    // existirian todavia cuando prim_common_pkg necesita el ancho de dato.
    //
    // Las guardas `ifndef permiten sobrescribir desde la linea de comandos:
    //   xvlog -d PRIM_ASYNC_FIFO_DATA_WIDTH=32 -d PRIM_ASYNC_FIFO_DEPTH=8
    //
    // Desde el Makefile, que es lo habitual:
    //   make DEFINES="PRIM_ASYNC_FIFO_DATA_WIDTH=32 PRIM_ASYNC_FIFO_DEPTH=8"

    `ifndef PRIM_ASYNC_FIFO_DEPTH
        `define PRIM_ASYNC_FIFO_DEPTH 4
    `endif

    `ifndef PRIM_ASYNC_FIFO_DATA_WIDTH
        `define PRIM_ASYNC_FIFO_DATA_WIDTH 16
    `endif

`endif
