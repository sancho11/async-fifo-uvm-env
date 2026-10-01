`ifndef PRIM_ASYNC_FIFO_TEST_03_DRAIN_SV
    `define PRIM_ASYNC_FIFO_TEST_03_DRAIN_SV

    // -------------------------------------------------------------------
    // TEST-03 - Drenaje
    //
    // Objetivo : recorrer toda la ocupacion observable desde el dominio de lectura
    // Estimulo : llenado como TEST-02, seguido de Depth lecturas espaciadas (max_delay alto)
    //            y SIN escrituras concurrentes
    // Ejercita : PROP-01, PROP-07, PROP-11
    // Cierra   : CP-05 completo -unico test que lo cierra-, CP-07 'reached'
    // Aprobado : cero UVM_ERROR y el FIFO vacio al final
    //
    // Especificacion completa en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_03_drain extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_03_drain)

        int unsigned n_items = PRIM_ASYNC_FIFO_DEPTH_P;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // La clase de relacion de frecuencias se fija con ratio_target en el
        // constructor, o se fuerza desde fuera con +RATIO_CLASS=<clase>.

        // -------------------------------------------------------------------
        // Llenar y despues drenar, en fases EXCLUSIVAS.
        //
        // El drenaje debe ser monotono: partiendo de lleno y leyendo de uno en
        // uno, rdepth toma sucesivamente Depth-1, Depth/2, 1 y 0, recorriendo
        // los cuatro bins de CP-05 en orden. Una sola escritura intercalada
        // rompe esa monotonia y se salta bins. Medido: con escrituras
        // concurrentes, CP-05 se quedaba en el 75 % en 3 de cada 15 corridas,
        // siendo el unico test que debe cerrarlo.
        // -------------------------------------------------------------------
        protected virtual task run_stimulus(uvm_phase phase);
            // A. Llenar. Sin lecturas.
            run_writes("wr_fill", n_items, 0);

            // Esperar a que el DOMINIO DE LECTURA vea el FIFO lleno.
            //
            // PROP-07: los dos dominios reportan ocupaciones distintas porque el
            // puntero remoto llega sincronizado con retardo. Si el drenaje
            // empieza antes de que el puntero de escritura haya cruzado, la
            // primera lectura muestrea un rdepth menor que Depth y se pierde el
            // bin 'almost_full'. Se espera a la condicion en lugar de a un
            // numero de ciclos: no depende de la relacion de relojes.
            while (env.rd_agent.vif.rdepth_o !== PRIM_ASYNC_FIFO_DEPTH_P) begin
                @(posedge env.rd_agent.vif.clk_rd_i);
            end

            // B. Drenar. Sin escrituras, y espaciado para que cada lectura
            //    quede claramente separada.  -> CP-05 completo, CP-07 'reached'
            run_reads("rd_drain", n_items, 5);

            settle();
        endtask

    endclass
`endif
