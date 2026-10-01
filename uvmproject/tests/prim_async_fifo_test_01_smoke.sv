`ifndef PRIM_ASYNC_FIFO_TEST_01_SMOKE_SV
    `define PRIM_ASYNC_FIFO_TEST_01_SMOKE_SV

    // -------------------------------------------------------------------
    // Tarea 4.3 — Smoke test. HITO 1.
    //
    // No busca esquinas ni cobertura: comprueba que la infraestructura
    // entera esta viva. Reset, unas escrituras y lecturas, y 0 UVM_ERROR.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_01_smoke extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_01_smoke)

        int unsigned n_items = 8;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        protected virtual task run_stimulus(uvm_phase phase);
            prim_wr_sequence_simple wr_seq;
            prim_rd_sequence_simple rd_seq;

            wr_seq = prim_wr_sequence_simple::type_id::create("wr_seq");
            rd_seq = prim_rd_sequence_simple::type_id::create("rd_seq");

            if (!wr_seq.randomize() with { n_items == local::n_items; max_delay <= 3; })
                `uvm_fatal("ALGORITHM_ISSUE", "No se pudo randomizar la secuencia de escritura")
            if (!rd_seq.randomize() with { n_items == local::n_items; max_delay <= 3; })
                `uvm_fatal("ALGORITHM_ISSUE", "No se pudo randomizar la secuencia de lectura")

            // En paralelo, no en lockstep: el handshake regula el flujo por si
            // solo, y desbalancear los ritmos es lo que hace aparecer full y empty.
            `uvm_info("TRACE","antes del fork", UVM_LOW)
            fork
                begin wr_seq.start(env.wr_agent.sequencer); `uvm_info("TRACE",$sformatf("wr_seq TERMINO @%0t",$time),UVM_LOW) end
                begin rd_seq.start(env.rd_agent.sequencer); `uvm_info("TRACE",$sformatf("rd_seq TERMINO @%0t",$time),UVM_LOW) end
            join
            `uvm_info("TRACE","tras el join", UVM_LOW)

            // Margen para que las ultimas transacciones lleguen a los monitores.
            repeat (20) @(posedge env.rd_agent.vif.clk_rd_i);
            `uvm_info("TRACE","tras el margen de 20 ciclos", UVM_LOW)
        endtask
    endclass
`endif
