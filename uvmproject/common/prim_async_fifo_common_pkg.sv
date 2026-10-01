`ifndef PRIM_ASYNC_FIFO_COMMON_PKG_SV
    `define PRIM_ASYNC_FIFO_COMMON_PKG_SV

    `include "uvm_macros.svh"
    `include "common/prim_async_fifo_defines.svh"

    // Tipos y clases base compartidos por los dos agentes y por el env.
    //
    // Existe como PAQUETE y no como cabecera incluida en cada agente porque un
    // `include duplicado crearia dos clases prim_item_base distintas —una por
    // paquete— y el scoreboard necesita que los items de ambos dominios
    // compartan la misma base.
    package prim_async_fifo_common_pkg;
        import uvm_pkg::*;

        `include "common/prim_async_fifo_types.sv"
        `include "common/prim_async_fifo_item_base.sv"
        `include "common/prim_async_fifo_reset_handler.sv"
        `include "common/prim_async_fifo_config_base.sv"
        `include "common/prim_async_fifo_agent_config_base.sv"
        `include "common/prim_async_fifo_coverage_base.sv"

    endpackage: prim_async_fifo_common_pkg

`endif
