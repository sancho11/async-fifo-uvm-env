`ifndef PRIM_ASYNC_FIFO_TEST_06_RESET_IN_FLIGHT_SV
    `define PRIM_ASYNC_FIFO_TEST_06_RESET_IN_FLIGHT_SV

    // -------------------------------------------------------------------
    // TEST-06 - Reset en vuelo
    //
    // Objetivo : activar el reset cuando hay algo que descartar y alguien esperando
    // Estimulo : llenado parcial o total, y activacion del reset MIENTRAS una transferencia esta
    //            pendiente (valid afirmada, ready baja), provocada con contrapresion
    // Ejercita : PROP-06a a 06d, PROP-12, PROP-13
    // Cierra   : CP-03 'during_transfer', CP-09 'while_partial' y 'while_full'
    // Aprobado : cero UVM_ERROR y el invariante lecturas + descartadas == escrituras cuadrado
    //
    // Especificacion completa en 3.5.1 del plan de verificacion.
    // -------------------------------------------------------------------
    class prim_async_fifo_test_06_reset_in_flight extends prim_async_fifo_test_base;
        `uvm_component_utils(prim_async_fifo_test_06_reset_in_flight)

        int unsigned n_items = PRIM_ASYNC_FIFO_DEPTH_P;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // -------------------------------------------------------------------
        // Dos resets provocados, cada uno con el FIFO en un estado distinto.
        //
        // El reset de encendido ya aporta CP-09 'while_empty' y CP-03
        // 'during_idle'. Lo que falta son los estados que solo se alcanzan
        // interrumpiendo trafico real:
        //
        //   Reset 1 : FIFO lleno y una escritura bloqueada esperando wready.
        //             -> CP-09 'while_full', CP-03 'during_transfer' en AMBOS
        //                agentes: el escritor tiene wvalid alta con wready baja,
        //                y el lector ve rvalid alta con su rready en reposo.
        //   Reset 2 : FIFO parcialmente lleno.
        //             -> CP-09 'while_partial'.
        //
        // Un reset que llega con el bus ocioso no ejercita la ruta de aborto:
        // los manejadores terminan procesos que no estaban conduciendo ni
        // recolectando nada, que es la parte con mas aristas del manejo de reset.
        // -------------------------------------------------------------------
        protected virtual task run_stimulus(uvm_phase phase);

            // ---- Reset 1: con el FIFO lleno y una transferencia de escritura pendiente ----
            run_writes("wr_fill", n_items, 0);

            fork
                // Esta escritura NO se completara: el FIFO esta lleno y nadie
                // lee. Se queda con wvalid afirmada esperando un wready que solo
                // llegaria si hubiera hueco. El manejador de reset la aborta.
                run_writes("wr_blocked", 1, 0);

                begin
                    wait_write_blocked();
                    asynchronously_reset_both_domains();
                end
            join_any

            wait_reset_released();

            // ---- Reset 2: con el FIFO parcialmente lleno ----
            run_writes("wr_partial", n_items / 2, 0);
            // run_writes retorna cuando el DRIVER termina, no cuando el monitor
            // ha publicado. Sin este margen el reset llega antes que los items y
            // el modelo del scoreboard esta vacio: CP-09 no ve 'while_partial'.
            repeat (6) @(posedge env.wr_agent.vif.clk_wr_i);
            asynchronously_reset_both_domains();
            wait_reset_released();

            // ---- Reset 3: CP-03b una transferencia de lectura pendiente ----
            run_writes("wr_fill", n_items, 0);
            // run_writes retorna cuando el DRIVER termina, no cuando el monitor
            // ha publicado. Sin este margen el reset llega antes que los items y
            // el modelo del scoreboard esta vacio: CP-09 no ve 'while_partial'.
            repeat (2) @(posedge env.rd_agent.vif.clk_rd_i);
            fork
                // Esta lectura NO se completara: el FIFO se vacía mientras se hacen
                // lecturas consecutivas. Sin embargo el reset interrumpe.
                run_reads("rd_drain", n_items, 0);

                begin
                    wait_new_read_after_valid_read();
                    asynchronously_reset_both_domains();
                end
            join_any
            wait_reset_released();


            // ---- Reset 4:  Plan de Verificacion -> Fuera de Alcance y Justificación
            // ---- -> Desfase en la liberacion del reset -> 2 (El caso que si interesa
            // ---- y que no depende de la randomizacion)
            run_writes("wr_fill", n_items, 0);
            // Tecnicamente este caso ya estaba cubierto porque al aplicar los reset por
            // ciclos de reloj y estos ser tan distintos entre si fuerzan que existan
            // varios ciclos de desface... Pero este caso en particular lo fuerza de forma
            // distinta.
            repeat (2) @(posedge env.rd_agent.vif.clk_rd_i);
            fork
                run_reads("rd_drain", n_items, 0);

                begin
                    wait_new_read_after_valid_read();
                    asynchronously_reset_both_domains(8,1);
                end
            join_any
            wait_reset_released();

            // ---- Trafico limpio posterior ----
            // Deja la corrida con lecturas reales y el FIFO vacio, de modo que
            // el invariante del scoreboard -lecturas + descartadas ==
            // escrituras- se compruebe con las tres magnitudes distintas de cero.
            run_writes("wr_clean", n_items, 0);
            run_reads("rd_clean", n_items, 2);

            settle();
        endtask

        // Espera a que la peticion de escritura este EFECTIVAMENTE bloqueada en
        // el cable: wvalid_i alta y wready_o baja. Es la misma condicion que
        // define 'write_is_blocked' en PROP-04 y PROP-05, y la que el componente
        // de cobertura muestrea para CP-03.
        //
        // Se espera a la condicion y no a un numero de ciclos: cuanto tarda el
        // driver en poner la peticion en el cable depende de la relacion de
        // relojes, que esta randomizada.
        // Se espera sobre mon_cb y NO sobre las señales crudas. Es la misma
        // vista que lee el componente de cobertura en su manejador de reset, y
        // el valor muestreado va un ciclo por detras del cable: esperando sobre
        // las señales fisicas, el reset llega cuando el clocking block todavia
        // muestra el ciclo anterior -con wready alta- y CP-03 registra
        // 'during_idle' pese a haber una transferencia bloqueada. Medido.
        protected virtual task wait_write_blocked();
            forever begin
                @(env.wr_agent.vif.mon_cb);
                if (env.wr_agent.vif.mon_cb.wvalid_i === 1'b1 &&
                    env.wr_agent.vif.mon_cb.wready_o === 1'b0) begin
                    break;
                end
            end
        endtask

        protected virtual task wait_new_read_after_valid_read();
            forever begin
                @(env.rd_agent.vif.mon_cb);
                if (env.rd_agent.vif.mon_cb.rvalid_o === 1'b1 &&
                    env.rd_agent.vif.mon_cb.rready_i === 1'b1) begin
                    break;
                end
            end
        endtask

        // Reset de los dos dominios a la vez.
        //
        // PROP-12: los dos resets son dos entregas sincronizadas de un mismo
        // reset logico, no dos dominios de reset independientes. Resetear uno
        // solo queda FUERA DEL CONTRATO, y el vigilante de reset del entorno lo
        // reporta como error. De ahi el fork/join.
        protected virtual task asynchronously_reset_both_domains(int unsigned n_cycles = 5, bit random_cycles_release_gap = 0);
            int unsigned cycles_wr;
            int unsigned cycles_rd;

            // Inicialización por defecto sin desfase
            cycles_wr = n_cycles;
            cycles_rd = n_cycles;

            // Desalinea la ACTIVACION del reset respecto al flanco.
            //
            // Sin esto el reset no es asincrono en la practica: los dos puntos de
            // llamada llegan desde un evento de reloj de escritura -la espera
            // sobre mon_cb y el repeat de posedge-, de modo que reset_assert() se
            // ejecuta siempre justo despues de un flanco de clk_wr_i. El gateado
            // asincrono de wvalid_i, que existe para reaccionar FUERA de flanco,
            // no se ejercitaria nunca en el escenario que lo justifica.
            //
            // Es una FRACCION del periodo y no un numero fijo de picosegundos:
            // los periodos estan randomizados entre 8 y 20 ns, asi que un valor
            // fijo seria un cuarto de ciclo con unos relojes y un ciclo entero
            // con otros.
            //
            // El rango excluye los extremos a proposito: 0 y el periodo completo
            // vuelven a alinear la activacion con un flanco, que es justo el caso
            // del que queremos salir.
            //
            // La liberacion NO se toca: PROP-13 exige que ocurra EN flanco, y de
            // eso ya se encarga reset_deassert().
            delay_within_write_cycle();

            if(random_cycles_release_gap) begin
                if (n_cycles > 1) begin
                    cycles_wr = $urandom_range(1, n_cycles);
                    cycles_rd = $urandom_range(1, n_cycles);
                end else begin
                    $warning("n_cycles <= 1, imposible aplicar gap sin causar underflow.");
                end
            end

            // Un solo retardo, antes del fork: PROP-12 establece que los dos
            // resets son dos entregas sincronizadas de UN MISMO reset logico. Dos
            // retardos independientes los convertirian en dos resets distintos, y
            // el vigilante del entorno lo reportaria como error.
            fork
                env.wr_agent.vif.do_reset(cycles_wr);
                env.rd_agent.vif.do_reset(cycles_rd);
            join_any
        endtask

        protected virtual task delay_within_write_cycle();
            real fraction;
            real delay_ns;

            fraction = real'($urandom_range(10, 90)) / 100.0;
            delay_ns = fraction * wr_period_ns;

            `uvm_info("RESET_PHASE", $sformatf("Asserting reset %0.3f ns after the edge (%0.0f%% of the write period)",
                                               delay_ns, fraction * 100.0), UVM_LOW)
            #(delay_ns);
        endtask

        protected virtual task wait_reset_released();
            fork
                env.wr_agent.wait_reset_end();
                env.rd_agent.wait_reset_end();
            join_any
        endtask

    endclass
`endif
