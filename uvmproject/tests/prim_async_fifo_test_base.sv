`ifndef PRIM_ASYNC_FIFO_TEST_BASE_SV
    `define PRIM_ASYNC_FIFO_TEST_BASE_SV

    class prim_async_fifo_test_base extends uvm_test;
        prim_async_fifo_env env;
        time timeout = 1ms;

        // Geometria temporal efectiva de la corrida.
        real wr_period_ns;
        real rd_period_ns;

        // Clase de relacion de frecuencias que este test quiere ejercitar.
        // Un test derivado la fija en su constructor; +RATIO_CLASS la sobrescribe.
        protected prim_async_fifo_ratio_class_e ratio_target = RATIO_ANY;
        protected prim_async_fifo_clock_cfg     clock_cfg;


        `uvm_component_utils(prim_async_fifo_test_base)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        // XSIM PLUSARGS WORKAROUND
        virtual function void start_of_simulation_phase(uvm_phase phase);
            int max_quit;
            int timeout_ns;

            super.start_of_simulation_phase(phase);

            // Ninguna corrida debe poder correr indefinidamente, pase lo que pase.
            // Con 'overridable = 1' un test concreto puede subirlo si lo necesita.
            uvm_root::get().set_timeout(timeout, 1);

            if($value$plusargs("UVM_TIMEOUT=%d", timeout_ns)) begin
                uvm_root::get().set_timeout(timeout_ns * 1ns, 1);
                `uvm_info("PLUSARG", $sformatf("Global timeout set to %0d ns", timeout_ns), UVM_LOW)
            end

            if($value$plusargs("UVM_MAX_QUIT_COUNT=%d", max_quit)) begin
                uvm_report_server::get_server().set_max_quit_count(max_quit);
                `uvm_info("PLUSARG", $sformatf("Max quit count set to %0d", max_quit), UVM_LOW)
            end

            // +UVM_OBJECTION_TRACE no tiene equivalente global: uvm_objection::trace_mode()
            // no es estatica, se activa sobre una objecion concreta. Si hace falta, la
            // linea seria uvm_test_done.trace_mode(1) o la objecion de la fase en cuestion.

            if($test$plusargs("UVM_CONFIG_DB_TRACE")) begin
                uvm_config_db_options::turn_on_tracing();
            end

            if($test$plusargs("UVM_RESOURCE_DB_TRACE")) begin
                uvm_resource_db_options::turn_on_tracing();
            end
        endfunction

        // ---------------------------------------------------------------
        // Estructura comun a todos los tests.
        //
        // La espera del reset y las objeciones se gestionan AQUI, no en cada
        // test derivado: arrancar estimulo con el reset activo hace que el
        // agente aborte las secuencias en t=0 (sequencer.stop_sequences()) y
        // el test termina sin conducir nada, en silencio. Como es una carrera
        // entre procesos que arrancan en el mismo instante, el fallo no es
        // reproducible de forma fiable. Por eso no se deja a criterio de
        // quien escriba el test.
        //
        // Un test concreto solo sobrescribe run_stimulus().
        // ---------------------------------------------------------------
        virtual task run_phase(uvm_phase phase);
            phase.raise_objection(this);

            env.wr_agent.wait_reset_end();
            env.rd_agent.wait_reset_end();
            `uvm_info("TEST_BASE", $sformatf("Power-on reset released at %0t. Starting stimulus.", $time), UVM_LOW)

            run_stimulus(phase);

            phase.drop_objection(this);
        endtask

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            // 1. Crear el ambiente
            env = prim_async_fifo_env::type_id::create("env", this);
            
            // 2. La clase de relacion puede forzarse desde la linea de comandos,
            //    que es como la regresion recorre las tres para cerrar los
            //    cruces CP-11 a CP-14 sin depender de que las semillas caigan
            //    donde tienen que caer.
            apply_ratio_class_plusarg();

            // 3. Geometria temporal, randomizada dentro de la clase pedida.
            set_test_periods(wr_period_ns, rd_period_ns);
            // 4. Los periodos explicitos mandan sobre todo lo anterior: son la
            //    via de depuracion dirigida y de reproduccion de una corrida.
            void'($value$plusargs("WR_PERIOD_NS=%f", wr_period_ns));
            void'($value$plusargs("RD_PERIOD_NS=%f", rd_period_ns));

            // 5. Publicacion unica del valor EFECTIVO.
            uvm_config_db #(real)::set(null, "*", "wr_period_ns", wr_period_ns);
            uvm_config_db #(real)::set(null, "*", "rd_period_ns", rd_period_ns);

            uvm_event_pool::get_global("clocks_go").trigger();
        endfunction

        // Geometria temporal de la corrida. Este es el UNICO sitio donde se
        // deciden los periodos: el testbench no tiene valores por defecto.
        //
        // Por defecto ambos son aleatorios en 8,0..20,0 ns, atados a la semilla.
        // El rango se elige para que el cociente rd/wr recorra las tres clases
        // de CP-10 —de 0,4 a 2,5— a lo largo de una regresion. Con periodos
        // fijos, N semillas ejercitarian N veces la misma relacion y los cruces
        // CP-11 a CP-14 quedarian permanentemente en un tercio.
        //
        // Un test que necesite una clase concreta sobrescribe este metodo en
        // lugar de fijar valores: dirigir la clase de relacion y dejar los
        // valores exactos aleatorios mantiene la variabilidad dentro del
        // escenario.
        virtual function void set_test_periods(ref real wr_period_ns, ref real rd_period_ns);
            clock_cfg = prim_async_fifo_clock_cfg::type_id::create("clock_cfg");
            clock_cfg.target = ratio_target;

            // La randomizacion esta atada a la semilla, de modo que la corrida
            // sigue siendo reproducible con -sv_seed.
            //
            // Un fallo aqui NO es un descuido de configuracion: significa que
            // las restricciones de clase son insatisfacibles dentro del rango de
            // periodos, es decir que el plan pide una relacion que el banco no
            // puede producir. Por eso es fatal y lo dice con el nombre de la clase.
            if (!clock_cfg.randomize()) begin
                `uvm_fatal("CLOCK_CFG",
                           $sformatf("Could not randomize the clock geometry for class %0s",
                                     ratio_target.name()))
            end

            wr_period_ns = clock_cfg.wr_period_ns();
            rd_period_ns = clock_cfg.rd_period_ns();

            `uvm_info("CLOCK_CFG", clock_cfg.convert2string(), UVM_LOW)
        endfunction

        // Permite a la regresion recorrer las tres clases sin escribir un test
        // por clase:  +RATIO_CLASS=wr_faster | similar | rd_faster | any
        protected virtual function void apply_ratio_class_plusarg();
            string requested;

            if (!$value$plusargs("RATIO_CLASS=%s", requested)) begin
                return;
            end

            case (requested)
                "any":       ratio_target = RATIO_ANY;
                "wr_faster": ratio_target = RATIO_WR_FASTER;
                "similar":   ratio_target = RATIO_SIMILAR;
                "rd_faster": ratio_target = RATIO_RD_FASTER;
                default:     `uvm_fatal("PLUSARG",
                                        $sformatf({"RATIO_CLASS=%0s is not a valid class. ",
                                                   "Valid: any, wr_faster, similar, rd_faster."},
                                                  requested))
            endcase

            `uvm_info("PLUSARG", $sformatf("Ratio class forced to %0s", ratio_target.name()), UVM_LOW)
        endfunction

        virtual function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            if ($test$plusargs("DUMP_TOPOLOGY")) dump_topology(this);
        endfunction

        // Gancho para los tests derivados. El base no conduce nada.
        protected virtual task run_stimulus(uvm_phase phase);
        endtask

        // ---------------------------------------------------------------
        // Veredicto de la corrida.
        //
        // POR QUE EL BANCO EMITE SU PROPIO VEREDICTO, y no se deduce del codigo
        // de salida ni de la ausencia de errores:
        //
        //   1. xsim devuelve codigo de salida 0 SIEMPRE -corrida correcta,
        //      UVM_FATAL, o test inexistente-. Comprobado. Un guion construido
        //      sobre '|| exit 1' no puede detectar ningun fallo.
        //   2. La ausencia de errores no es exito. Un registro truncado, un
        //      simulador que ha muerto o un test que no llego a arrancar
        //      producen todos un registro sin errores. Nos ocurrio: un bloqueo
        //      mutuo dejo una simulacion vacia que "paso" en verde.
        //   3. Las aserciones emiten $error, que no incrementa UVM_ERROR.
        //      Tambien nos ocurrio: un falso positivo de PROP-13 disparando en
        //      cada reset, con el resumen diciendo "UVM_ERROR: 0".
        //
        // De ahi un MARCADOR POSITIVO cuya AUSENCIA es fallo. El guion de
        // regresion no busca errores: busca el marcador, y si no esta, la
        // corrida no paso, sin importar por que.
        // ---------------------------------------------------------------
        virtual function void final_phase(uvm_phase phase);
            uvm_report_server svr;
            int unsigned n_errors;
            int unsigned n_fatals;
            int unsigned n_assert_fails;

            super.final_phase(phase);

            svr      = uvm_report_server::get_server();
            n_errors = svr.get_severity_count(UVM_ERROR);
            n_fatals = svr.get_severity_count(UVM_FATAL);

            // Las aserciones no pasan por el report server: se leen del contador
            // de cada interfaz.
            n_assert_fails = env.wr_agent.vif.assert_fail_count +
                             env.rd_agent.vif.assert_fail_count;

            `uvm_info("VERDICT", $sformatf("uvm_errors=%0d uvm_fatals=%0d assertion_failures=%0d",
                                           n_errors, n_fatals, n_assert_fails), UVM_NONE)

            if (run_passed(n_errors, n_fatals, n_assert_fails)) begin
                $display("*** TEST PASSED ***");
            end
            else begin
                $display("*** TEST FAILED ***");
            end
        endfunction

        // Criterio de aprobado. Se aisla en un metodo virtual porque la familia
        // de inyeccion de fallos lo INVIERTE: alli el test pasa cuando el
        // comprobador dispara, y una corrida limpia es el fallo.
        protected virtual function bit run_passed(int unsigned n_errors,
                                                  int unsigned n_fatals,
                                                  int unsigned n_assert_fails);
            return (n_errors == 0) && (n_fatals == 0) && (n_assert_fails == 0);
        endfunction

        // ---------------------------------------------------------------
        // Auxiliares de estimulo.
        //
        // El patron -crear la secuencia, randomizarla, arrancarla- se repite en
        // todos los tests dirigidos. Concentrarlo aqui deja en cada test solo lo
        // que de verdad lo distingue: cuantos items, con que ritmo, en que orden
        // y sobre que dominio.
        //
        // Arrancan de forma SECUENCIAL, que es lo que un test dirigido necesita:
        // una fase que conduce los dos dominios a la vez deja el resultado a
        // merced de que retardo saque el sorteo, y con el deja de ser
        // determinista. Para la concurrencia deliberada estan los fork del test
        // que la persigue.
        // ---------------------------------------------------------------
        protected virtual task run_writes(string name, int unsigned n, int unsigned max_dly,
                                      int unsigned min_dly = 0);
            prim_wr_sequence_simple seq;
            seq = prim_wr_sequence_simple::type_id::create(name);
            if (!seq.randomize() with { n_items == n;
                                        max_delay <= max_dly;
                                        min_delay == min_dly; }) begin
                `uvm_fatal("ALGORITHM_ISSUE", $sformatf("Could not randomize %0s", name))
            end
            seq.start(env.wr_agent.sequencer);
        endtask

        protected virtual task run_reads(string name, int unsigned n, int unsigned max_dly,
                                      int unsigned min_dly = 0);
            prim_rd_sequence_simple seq;
            seq = prim_rd_sequence_simple::type_id::create(name);
            if (!seq.randomize() with { n_items == n;
                                        max_delay <= max_dly;
                                        min_delay == min_dly; }) begin
                `uvm_fatal("ALGORITHM_ISSUE", $sformatf("Could not randomize %0s", name))
            end
            seq.start(env.rd_agent.sequencer);
        endtask

        // Margen para que las ultimas transacciones lleguen a los monitores
        // antes de que el test baje la objecion.
        protected virtual task settle(int unsigned n_cycles = 4);
            repeat (n_cycles) @(posedge env.rd_agent.vif.clk_rd_i);
        endtask

        // Herramienta para hacer un mapa de la arquitectura de pruebas.
        function void dump_topology(uvm_component c, int lvl = 0);
            uvm_component kids[$];
            string pad = {lvl*3{" "}};
            $display("   %s%s  (%s)", pad, c.get_name(), c.get_type_name());
            c.get_children(kids);
            foreach (kids[i]) dump_topology(kids[i], lvl + 1);
        endfunction
    endclass
`endif