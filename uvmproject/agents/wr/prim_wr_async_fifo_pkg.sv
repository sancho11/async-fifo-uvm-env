`ifndef PRIM_WR_ASYNC_FIFO_PKG_SV
    `define PRIM_WR_ASYNC_FIFO_PKG_SV

    //Incluir macros UVM
    `include "uvm_macros.svh"


    //Definicion del PKG
    package prim_wr_async_fifo_pkg;
        // Importar todo lo definido en el UVM PKG:
        import uvm_pkg::*;
        import prim_async_fifo_common_pkg::*;

        //Incluir los componentes requeridos por el agente
        `include "agents/wr/prim_wr_item_drv.sv"
        `include "agents/wr/prim_wr_item_mon.sv"
        `include "agents/wr/prim_wr_agent_config.sv"
        `include "agents/wr/prim_wr_driver.sv"
        `include "agents/wr/prim_wr_monitor.sv"
        `include "agents/wr/prim_wr_coverage.sv"
        `include "agents/wr/prim_wr_sequencer.sv"
        `include "agents/wr/prim_wr_async_fifo_agent.sv"
        `include "agents/wr/sequences/prim_wr_sequence_base.sv"
        `include "agents/wr/sequences/prim_wr_sequence_simple.sv"

    endpackage: prim_wr_async_fifo_pkg

`endif