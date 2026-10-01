`ifndef PRIM_ASYNC_FIFO_TEST_07_FAULT_INJECTION_SV
    `define PRIM_ASYNC_FIFO_TEST_07_FAULT_INJECTION_SV

    // -------------------------------------------------------------------
    // TEST-08 - Inyeccion de fallos (familia)
    //
    // Objetivo : demostrar que cada comprobador detecta la violacion que dice
    //            detectar. Un comprobador que nunca ha fallado no esta
    //            verificado: puede ser correcto, o puede no estar conectado.
    // Estimulo : el de TEST-01, sobre un entorno con UN defecto inyectado.
    // Ejercita : la infraestructura de comprobacion, no el DUT.
    // Cierra   : ningun punto de cobertura.
    // Aprobado : INVERTIDO. El test pasa cuando el comprobador esperado SI
    //            dispara, con su identificador. Una corrida limpia es un fallo.
    //
    // UNA CLASE, UN DEFECTO POR CORRIDA.
    //
    // El defecto se elige con +FAULT=<id>, y la regresion itera sobre los ids.
    // No se inyectan varios a la vez a proposito: con dos defectos activos no
    // se puede atribuir que error vino de cual, los fallos interactuan -datos
    // corruptos mas lecturas duplicadas producen una sopa de errores- y un
    // comprobador que hubiera dejado de funcionar quedaria enmascarado por
    // otro que si dispara. La atribucion es justamente lo que este test existe
    // para demostrar.
    //
    // Catalogo de defectos en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_08_fault_injection extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_08_fault_injection)

        // Identificador del defecto a inyectar, desde +FAULT=<id>.
        protected string fault_id;

        // Identificador de informe que se espera ver disparar.
        protected string expected_report_id;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // ---------------------------------------------------------------
        // TODO (implementacion)
        //
        // build_phase:
        //   1. Leer +FAULT=<id> y fijar expected_report_id segun el catalogo.
        //   2. Instalar el defecto. Dos mecanismos segun su naturaleza:
        //      - estatico  -> type override de factory sobre el componente
        //                     afectado (monitor, driver) por una variante
        //                     defectuosa.
        //      - temporal  -> callback, cuando el defecto debe activarse en un
        //                     instante concreto de la corrida.
        //   3. Preparar la observacion del disparo. DOS mecanismos, segun donde
        //      viva el comprobador:
        //      - Mecanismo I, comprobador en un componente UVM (scoreboard):
        //        un uvm_report_catcher intercepta el id esperado, lo cuenta y
        //        lo degrada a UVM_INFO. Sin eso la corrida termina con
        //        UVM_ERROR > 0 y la regresion la marcaria como fallida, cuando
        //        en esta familia ese error es el resultado buscado.
        //      - Mecanismo II, comprobador en una asercion de la interfaz:
        //        las aserciones emiten $error y NO pasan por el sistema de
        //        reporte de UVM -decision deliberada, ver 7.3-, de modo que un
        //        report catcher no puede verlas. Se leen por un contador de
        //        fallos en la propia interfaz, incrementado en el bloque de
        //        accion junto al $error.
        //
        // check_phase:
        //   - Si el contador del catcher es 0 -> uvm_error: el comprobador NO
        //     detecto la violacion. Es el unico fallo real de este test.
        //   - Si aparecieron errores de OTROS identificadores -> uvm_error: la
        //     inyeccion no esta acotada y el resultado no es atribuible.
        // ---------------------------------------------------------------

        protected virtual task run_stimulus(uvm_phase phase);
            `uvm_fatal("NOT_IMPLEMENTED",
                       "TEST-08 is not implemented yet. An empty test would pass silently.")
        endtask

    endclass
`endif
