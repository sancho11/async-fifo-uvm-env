`ifndef PRIM_ASYNC_FIFO_TEST_07_CDC_DELAY_SV
    `define PRIM_ASYNC_FIFO_TEST_07_CDC_DELAY_SV

    // -------------------------------------------------------------------
    // TEST-07 - Latencia de cruce con instrumentacion CDC
    //
    // Objetivo : ejercitar PROP-09, la tolerancia del diseno a una latencia de
    //            cruce variable, que ningun otro test ejercita
    // Estimulo : trafico concurrente en ambos dominios con hueco GARANTIZADO
    //            entre transferencias, bajo relojes de frecuencia parecida
    // Ejercita : PROP-09 y, de forma sostenida, PROP-01 a PROP-03 y PROP-07
    // Cierra   : ningun punto en exclusiva. Aporta a CP-01, CP-02 y a los
    //            bins de relojes parecidos, pero su razon de ser no es la
    //            cobertura sino ejercitar una propiedad que ningun otro test
    //            ejercita.
    // Aprobado : cero UVM_ERROR y cero fallos de asercion
    //
    // -------------------------------------------------------------------
    // POR QUE ESTE TEST EXISTE Y POR QUE SU ESTIMULO ES TAN ESPECIFICO
    // -------------------------------------------------------------------
    // El sincronizador de OpenTitan instancia prim_cdc_rand_delay, que modela
    // la captura incoherente entre bits al muestrear un bus asincrono. Esta
    // apagado por partida doble: su cuerpo vive dentro de un `ifdef SIMULATION
    // y, aun con el definido, solo actua si se le pasa un plusarg. Este test
    // NO tiene sentido sin ambos:
    //
    //   make run TEST=prim_async_fifo_test_07_cdc_delay \
    //        DEFINES=SIMULATION PLUSARGS=cdc_instrumentation_enabled=1
    //
    // La cabecera de ese modulo fija su envolvente de validez:
    //
    //   "the delay should cause the input to be skipped by at most a single
    //    cycle"
    //
    // Fuera de el, el modulo mezcla el puntero de origen con el contenido del
    // primer flop estando este varios pasos atras, y produce valores Gray que
    // nunca estuvieron en el cable. El resto de la campana lo excede a
    // proposito: cerrar CP-12 a CP-15 exige barrer relaciones de frecuencia de
    // 0,4 a 2,5. De ahi que este test sea aparte y no una clase mas del barrido.
    //
    // Respetar el envolvente exige dos cosas a la vez:
    //
    //   1. RELOJES PARECIDOS. ratio_target = RATIO_SIMILAR acota el cociente a
    //      [0,92 ; 1,08].
    //   2. HUECO GARANTIZADO entre transferencias. No basta con permitirlo via
    //      max_delay, que es solo una cota superior: con min_delay = 0 el
    //      sorteo puede dar transferencias consecutivas, el puntero avanza en
    //      ciclos seguidos y el flop destino se queda atras. Medido: TEST-01
    //      bajo 'similar' falla 2 de cada 20 semillas por esa razon.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_07_cdc_delay extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_07_cdc_delay)

        // Volumen suficiente para que los punteros crucen muchas veces y den
        // la vuelta varias; el valor no es critico.
        int unsigned n_items = 40;

        // El hueco minimo es lo que mantiene el modelo dentro de su envolvente.
        // Con cociente <= 1,08 bastaria min_dly = 1; se usa 2 por margen.
        int unsigned min_dly = 2;
        int unsigned max_dly = 4;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ratio_target = RATIO_SIMILAR;
        endfunction

        protected virtual task run_stimulus(uvm_phase phase);
            // El envolvente depende de la clase de reloj, y +RATIO_CLASS puede
            // sobrescribir lo fijado en el constructor. Si eso ocurre el test
            // sigue corriendo, pero deja de medir lo que dice medir.
            if (ratio_target != RATIO_SIMILAR) begin
                `uvm_warning("CDC_ENVELOPE",
                    $sformatf({"Ratio class is %0s, not RATIO_SIMILAR. The CDC ",
                               "instrumentation model is outside its documented ",
                               "envelope and any failure is an artifact of the ",
                               "model, not a defect of the DUT."},
                              ratio_target.name()))
            end

            // Trafico concurrente: lo que estresa el cruce es que ambos
            // punteros avancen a la vez, no la ocupacion del FIFO.
            fork
                run_writes("wr_cdc", n_items, max_dly, min_dly);
                run_reads ("rd_cdc", n_items, max_dly, min_dly);
            join

            settle();
        endtask

    endclass
`endif
