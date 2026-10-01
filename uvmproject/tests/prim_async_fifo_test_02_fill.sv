`ifndef PRIM_ASYNC_FIFO_TEST_02_FILL_SV
    `define PRIM_ASYNC_FIFO_TEST_02_FILL_SV

    // -------------------------------------------------------------------
    // TEST-02 - Llenado
    //
    // Objetivo : llevar la ocupacion hasta Depth y mantenerla
    // Estimulo : escritura con n_items == Depth y max_delay == 0, sin lecturas durante el llenado;
    //            drenaje posterior para no terminar con datos dentro
    // Ejercita : PROP-08, PROP-10
    // Cierra   : CP-04 'full', CP-06 'reached'
    // Aprobado : cero UVM_ERROR; NO debe dispararse el umbral de transaccion atascada
    //
    // Especificacion completa en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_02_fill extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_02_fill)

        // Cada fase mueve exactamente Depth items: es lo que hace falta para
        // llevar el FIFO de vacio a lleno y de vuelta, sin depender de ningun
        // reparto arbitrario. Escribir mas sin nadie leyendo bloquea al driver.
        int unsigned n_items = PRIM_ASYNC_FIFO_DEPTH_P;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // La clase de relacion de frecuencias se fija con ratio_target en el
        // constructor, o se fuerza desde fuera con +RATIO_CLASS=<clase>.

        // -------------------------------------------------------------------
        // Cuatro fases EXCLUSIVAS: en ninguna conducen los dos dominios a la vez.
        //
        // Es la condicion de determinismo del test. Con ambos dominios activos,
        // 'max_delay' solo fija una COTA: una semilla puede dar al lector un
        // retardo menor que al escritor y, bajo relojes rd_faster, el FIFO no
        // llega a llenarse nunca. Medido: con fases concurrentes, CP-06 caia al
        // 0 % en 1 de cada 15 corridas -el test de llenado no llenaba, y pasaba
        // en verde-.
        //
        // Las fases C y D existen para CP-06 'abandoned': abandonar la condicion
        // de lleno solo se registra en una transaccion de ESCRITURA posterior,
        // asi que despues de vaciar hay que volver a escribir.
        // -------------------------------------------------------------------
        protected virtual task run_stimulus(uvm_phase phase);
            // A. Llenar. Sin lecturas: wdepth llega a Depth con independencia
            //    de la relacion de relojes.   -> CP-04 completo, CP-06 'reached'
            run_writes("wr_fill", n_items, 0);

            // B. Vaciar. Sin escrituras.
            run_reads("rd_drain", n_items, 3);

            // Esperar a que el DOMINIO DE ESCRITURA vea el FIFO vacio.
            //
            // PROP-07: wdepth_o es conservador por exceso, porque el puntero de
            // lectura llega sincronizado con retardo. Si la fase C empieza antes
            // de que los vaciados hayan cruzado, la primera escritura encuentra
            // wdepth = Depth-1, la acepta y vuelve a dejarlo en Depth: la
            // transicion es 1 => 1 y no cae en ningun bin, de modo que
            // 'abandoned' no se registra. Medido: sin esta espera, CP-06 caia al
            // 50 % en 3 de cada 5 semillas bajo rd_faster.
            while (env.wr_agent.vif.wdepth_o !== 0) begin
                @(posedge env.wr_agent.vif.clk_wr_i);
            end

            // C. Volver a escribir: la primera escritura ve wdepth < Depth y
            //    registra la transicion.       -> CP-06 'abandoned'
            run_writes("wr_refill", n_items, 0);

            // D. Vaciar de nuevo para terminar sin datos dentro del DUT.
            run_reads("rd_final", n_items, 3);

            settle();
        endtask

    endclass
`endif
