`ifndef PRIM_ASYNC_FIFO_TEST_PKG_SV
    `define PRIM_ASYNC_FIFO_TEST_PKG_SV

    //Incluir macros UVM
    `include "uvm_macros.svh"


    //Definicion del PKG
    package prim_async_fifo_test_pkg;
        // Importar todo lo definido en el UVM PKG:
        import uvm_pkg::*;
        import prim_async_fifo_common_pkg::*;

        //Incluir los pkg de los agentes (lectura/escritura fifo asincrono)
        import prim_rd_async_fifo_pkg::*;
        import prim_wr_async_fifo_pkg::*;

        //El environment y demas componentes del testbench
        import prim_async_fifo_pkg::*;


        //Tests
        `include "tests/prim_async_fifo_clock_cfg.sv"
        `include "tests/prim_async_fifo_test_base.sv"
        `include "tests/prim_async_fifo_test_01_smoke.sv"
        `include "tests/prim_async_fifo_test_02_fill.sv"
        `include "tests/prim_async_fifo_test_03_drain.sv"
        `include "tests/prim_async_fifo_test_04_concurrent.sv"
        `include "tests/prim_async_fifo_test_05_random.sv"
        `include "tests/prim_async_fifo_test_06_reset_in_flight.sv"
        `include "tests/prim_async_fifo_test_07_cdc_delay.sv"
        `include "tests/prim_async_fifo_test_08_fault_injection.sv"

    endpackage: prim_async_fifo_test_pkg

`endif