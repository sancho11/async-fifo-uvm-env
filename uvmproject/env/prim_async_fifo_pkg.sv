`ifndef PRIM_ASYNC_FIFO_PKG_SV
    `define PRIM_ASYNC_FIFO_PKG_SV

    //Incluir macros UVM
    `include "uvm_macros.svh"


    //Definicion del PKG
    package prim_async_fifo_pkg;
        // Importar todo lo definido en el UVM PKG:
        import uvm_pkg::*;
        import prim_async_fifo_common_pkg::*;

        //Incluir los pkg de los agentes (lectura/escritura fifo asincrono)
        import prim_rd_async_fifo_pkg::*;
        import prim_wr_async_fifo_pkg::*;

        //Definicion de clases de puertos comunes a scoreboard y coverage
        `uvm_analysis_imp_decl(_wr)
        `uvm_analysis_imp_decl(_rd)

        //Modulos del ambiente
        `include "env/prim_async_fifo_env_config.sv"
        `include "env/prim_async_fifo_scoreboard.sv"
        `include "env/prim_async_fifo_coverage.sv"
        `include "env/prim_async_fifo_env.sv"

    endpackage: prim_async_fifo_pkg

`endif