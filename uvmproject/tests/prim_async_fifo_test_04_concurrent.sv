`ifndef PRIM_ASYNC_FIFO_TEST_04_CONCURRENT_SV
    `define PRIM_ASYNC_FIFO_TEST_04_CONCURRENT_SV

    // -------------------------------------------------------------------
    // TEST-04 - Concurrencia a maximo caudal
    //
    // Objetivo : someter el cruce de dominios a la maxima exigencia, con ambos punteros
    //            avanzando en ciclos consecutivos
    // Estimulo : ambos agentes con max_delay == 0 y n_items multiplo de Depth, en fork/join
    // Ejercita : PROP-01 a PROP-03 sobre secuencia larga; PROP-07 y PROP-09 de forma sostenida
    // Cierra   : CP-01 y CP-02 'back_to_back', CP-08 con vueltas repetidas
    // Aprobado : cero UVM_ERROR
    //
    // Especificacion completa en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_04_concurrent extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_04_concurrent)

        int unsigned n_items = 128;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // Para cerrar los cruces CP-11 a CP-14 este test debe ejecutarse bajo
        // cada relacion de frecuencias. Sobrescribir set_test_periods() para
        // restringir la CLASE de relacion, dejando los valores exactos
        // aleatorios: dirigir la clase y no los valores mantiene la
        // variabilidad dentro del escenario (3.5).
        //
        // virtual function void set_test_periods(ref real wr_period_ns,
        //                                        ref real rd_period_ns);
        // endfunction

        protected virtual task run_stimulus(uvm_phase phase);
            prim_wr_sequence_simple wr_seq;
            prim_rd_sequence_simple rd_seq;

            wr_seq = prim_wr_sequence_simple::type_id::create("wr_seq");
            rd_seq = prim_rd_sequence_simple::type_id::create("rd_seq");

            if (!wr_seq.randomize() with { n_items == local::n_items; max_delay <= 0; })
                `uvm_fatal("ALGORITHM_ISSUE", "No se pudo randomizar la secuencia de escritura")
            if (!rd_seq.randomize() with { n_items == local::n_items; max_delay <= 0; })
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
