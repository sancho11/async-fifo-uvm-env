`ifndef PRIM_RD_ASYNC_FIFO_PKG_SV
    `define PRIM_RD_ASYNC_FIFO_PKG_SV

    //Incluir macros UVM
    `include "uvm_macros.svh"


    //Definicion del PKG
    package prim_rd_async_fifo_pkg;
        // Importar todo lo definido en el UVM PKG:
        import uvm_pkg::*;
        import prim_async_fifo_common_pkg::*;

        //Incluir los componentes requeridos por el agente
        `include "agents/rd/prim_rd_item_drv.sv"
        `include "agents/rd/prim_rd_item_mon.sv"
        `include "agents/rd/prim_rd_agent_config.sv"
        `include "agents/rd/prim_rd_driver.sv"
        `include "agents/rd/prim_rd_monitor.sv"
        `include "agents/rd/prim_rd_coverage.sv"
        `include "agents/rd/prim_rd_sequencer.sv"
        `include "agents/rd/prim_rd_async_fifo_agent.sv"
        `include "agents/rd/sequences/prim_rd_sequence_base.sv"
        `include "agents/rd/sequences/prim_rd_sequence_simple.sv"

        
    endpackage: prim_rd_async_fifo_pkg

`endif