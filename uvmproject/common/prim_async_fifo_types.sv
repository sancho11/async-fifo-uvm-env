`ifndef PRIM_ASYNC_FIFO_TYPES_SV
    `define PRIM_ASYNC_FIFO_TYPES_SV

    // Se incluye DENTRO de prim_async_fifo_common_pkg, por eso puede declarar parameters
    // y typedefs sin envoltorio propio.

    // Geometria del DUT. Las macros de prim_defines.svh existen SOLO para poder
    // sobrescribir desde la linea de comandos (-d PRIM_ASYNC_FIFO_DEPTH=8); a partir de
    // aqui todo viaja como parametros de paquete, que el testbench importa. Asi
    // la geometria esta definida en un unico sitio.
    parameter int unsigned PRIM_ASYNC_FIFO_DEPTH_P = `PRIM_ASYNC_FIFO_DEPTH;
    parameter int unsigned PRIM_ASYNC_FIFO_DATA_W  = `PRIM_ASYNC_FIFO_DATA_WIDTH;

    // Ancho del contador de ocupacion. El DUT lo deriva igual: el contador
    // cuenta 0..Depth inclusive, de ahi el +1.
    parameter int unsigned PRIM_ASYNC_FIFO_DEPTH_W = $clog2(PRIM_ASYNC_FIFO_DEPTH_P + 1);

    // Carga util del FIFO.
    typedef bit [PRIM_ASYNC_FIFO_DATA_W-1:0] prim_async_fifo_data;

    // Ocupacion reportada por wdepth_o / rdepth_o.
    typedef bit [PRIM_ASYNC_FIFO_DEPTH_W-1:0] prim_async_fifo_depth;

    // Tipos de virtual interface. Se parametrizan explicitamente en vez de
    // confiar en los valores por defecto de la interface: asi un -d en la linea
    // de comandos mueve el testbench y estos typedefs a la vez.
    typedef virtual prim_async_fifo_wr_if #(
        .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
        .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
        .PRIM_ASYNC_FIFO_DATA_WIDTH (PRIM_ASYNC_FIFO_DATA_W)
    ) prim_wr_vif;

    typedef virtual prim_async_fifo_rd_if #(
        .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
        .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
        .PRIM_ASYNC_FIFO_DATA_WIDTH (PRIM_ASYNC_FIFO_DATA_W)
    ) prim_rd_vif;

    //Handles a las interfaces atravez de sus modports.
    //Write
    typedef virtual prim_async_fifo_wr_if #(
    .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
    .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
    .PRIM_ASYNC_FIFO_DATA_WIDTH(PRIM_ASYNC_FIFO_DATA_W)
    ).drv  prim_wr_drv_vif;

    typedef virtual prim_async_fifo_wr_if #(
    .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
    .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
    .PRIM_ASYNC_FIFO_DATA_WIDTH(PRIM_ASYNC_FIFO_DATA_W)
    ).mon  prim_wr_mon_vif;

    //Read
    typedef virtual prim_async_fifo_rd_if #(
    .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
    .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
    .PRIM_ASYNC_FIFO_DATA_WIDTH(PRIM_ASYNC_FIFO_DATA_W)
    ).drv  prim_rd_drv_vif;

    typedef virtual prim_async_fifo_rd_if #(
    .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
    .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
    .PRIM_ASYNC_FIFO_DATA_WIDTH(PRIM_ASYNC_FIFO_DATA_W)
    ).mon  prim_rd_mon_vif;

`endif
