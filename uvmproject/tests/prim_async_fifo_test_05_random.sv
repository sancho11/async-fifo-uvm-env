`ifndef PRIM_ASYNC_FIFO_TEST_05_RANDOM_SV
    `define PRIM_ASYNC_FIFO_TEST_05_RANDOM_SV

    // -------------------------------------------------------------------
    // TEST-05 - Aleatorio con relacion de frecuencias variable
    //
    // Objetivo : explorar el espacio de estimulo sin dirigir nada
    // Estimulo : n_items y max_delay aleatorios en ambos dominios; periodos derivados de la
    //            semilla, que es el comportamiento por defecto del test base
    // Ejercita : todas, de forma no dirigida
    // Cierra   : CP-10; condicion necesaria para CP-12 a CP-15
    // Aprobado : cero UVM_ERROR en todas las semillas de la regresion
    //
    // Especificacion completa en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_05_random extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_05_random)

        int unsigned n_items =  $urandom_range(1024, 2048);      // aleatorio, atado a la semilla
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            env.scoreboard.expect_empty_at_end = 1;
        endfunction

        protected virtual task run_stimulus(uvm_phase phase);
            prim_wr_sequence_simple wr_seq;
            prim_rd_sequence_simple rd_seq;

            wr_seq = prim_wr_sequence_simple::type_id::create("wr_seq");
            rd_seq = prim_rd_sequence_simple::type_id::create("rd_seq");

            if (!wr_seq.randomize() with { n_items == local::n_items; })
                `uvm_fatal("ALGORITHM_ISSUE", "No se pudo randomizar la secuencia de escritura")
            if (!rd_seq.randomize() with { n_items == local::n_items; })
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
            repeat (4) @(posedge env.rd_agent.vif.clk_rd_i);
            `uvm_info("TRACE","tras el margen de 4 ciclos", UVM_LOW)
        endtask

    endclass
`endif
