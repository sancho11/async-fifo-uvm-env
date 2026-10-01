`ifndef PRIM_ASYNC_FIFO_COVERAGE_SV
    `define PRIM_ASYNC_FIFO_COVERAGE_SV
    
    //Declaracion de clase del puerto reset
    `uvm_analysis_imp_decl(_reset)

    class prim_async_fifo_coverage extends prim_async_fifo_coverage_base implements prim_async_fifo_reset_handler;
        //Port for receiving the collected item
        uvm_analysis_imp_wr#(prim_wr_item_mon, prim_async_fifo_coverage) wr_imp;
        uvm_analysis_imp_rd#(prim_rd_item_mon, prim_async_fifo_coverage) rd_imp;
        uvm_analysis_imp_reset#(int unsigned, prim_async_fifo_coverage)  reset_imp;

        `uvm_component_utils(prim_async_fifo_coverage)

        //Contadores para CP-08
        protected int unsigned wr_accepted_count;
        protected int unsigned rd_accepted_count;

        // Sentinel sampled on reset: breaks the transition chain so that a full or
        // empty condition cleared by reset is not recorded as 'abandoned'.
        localparam int COND_RESET_BOUNDARY = -1;

        // Umbrales de CP-10, expresados en centesimas del cociente
        // rd_period_ns / wr_period_ns (3.4.7 del plan de verificacion).
        // Se declaran una sola vez porque el mismo coverpoint aparece en varios
        // covergroups: ademas de CP-10 es el operando comun de CP-12 y CP-13, y
        // un cruce solo puede formarse entre coverpoints del MISMO covergroup.
        localparam int unsigned RATIO_RD_FASTER_MAX = 89;    // cociente < 0,90
        localparam int unsigned RATIO_SIMILAR_MIN   = 90;    // 0,90 <= cociente <= 1,10
        localparam int unsigned RATIO_SIMILAR_MAX   = 110;
        localparam int unsigned RATIO_WR_FASTER_MIN = 111;   // cociente > 1,10

        //Real variables for getting the periods
        real wr_period_ns;
        real rd_period_ns;
        int unsigned ratio;

        //Config
        prim_async_fifo_env_config env_config;

        // -------------------------------------------------------------------
        // Contabilidad por BIN.
        //
        // POR QUE HACE FALTA: SystemVerilog no ofrece ninguna API para enumerar
        // los bins de un covergroup ni sus aciertos. get_inst_coverage() da un
        // porcentaje, y un 75 % dice que falta uno de cuatro sin decir CUAL. El
        // criterio de aprobado necesita lo segundo: un test dirigido debe
        // demostrar que lleno EL bin del que es responsable, no que llego a un
        // porcentaje. La via del simulador esta cerrada: xcrg exige licencia PRO.
        //
        // POR QUE NO ES UN RIESGO: llevar la cuenta en paralelo duplica la
        // clasificacion que el covergroup ya hace por dentro, y dos
        // clasificaciones del mismo valor pueden desincronizarse. Por eso
        // check_bin_bookkeeping() compara, en cada corrida, el porcentaje
        // derivado de estos contadores con el que reporta el covergroup. Si
        // discrepan, la corrida falla. La duplicacion queda verificada en lugar
        // de supuesta.
        //
        // Clave: "<CP>.<bin>". El array se PREDECLARA completo en el constructor,
        // de modo que un bin con cero aciertos aparece en el informe como cero y
        // no como ausente: la diferencia entre "no se alcanzo" y "nadie lo midio".
        // -------------------------------------------------------------------
        // bin_hits, declare_bin() y record_bin() viven en
        // prim_async_fifo_coverage_base. Declararlos aqui los OCULTARIA: los
        // record_bin() escribirian en el array de esta clase mientras dump_bins()
        // -metodo de la base- leeria el de la base, vacio. Ocurrio, y lo detecto
        // check_bin_bookkeeping() en la primera corrida.

        // Cuantos bins de un punto tienen al menos un acierto.
        // Clasificadores. Replican los bins de los covergroups; que la replica
        // sea fiel lo comprueba check_bin_bookkeeping().
        protected function string occupancy_bin(int unsigned depth);
            case (depth)
                0                            : return "empty";
                1                            : return "one";
                PRIM_ASYNC_FIFO_DEPTH_P/2    : return "half";
                PRIM_ASYNC_FIFO_DEPTH_P-1    : return "almost_full";
                PRIM_ASYNC_FIFO_DEPTH_P      : return "full";
                default                      : return "";
            endcase
        endfunction

        protected function string ratio_bin(int unsigned pct);
            if (pct <= RATIO_RD_FASTER_MAX) return "rd_faster";
            if (pct <= RATIO_SIMILAR_MAX)   return "similar";
            return "wr_faster";
        endfunction

        // Estado previo de las condiciones limite, para replicar los bins de
        // transicion. COND_RESET_BOUNDARY entra igual que en el covergroup, de
        // modo que una condicion borrada por el reset no cuenta como abandonada.
        protected int prev_full_state  = COND_RESET_BOUNDARY;
        protected int prev_empty_state = COND_RESET_BOUNDARY;

        protected function void record_transition(string cp, int prev, int curr);
            if (prev == 0 && curr == 1) record_bin({cp, ".reached"});
            if (prev == 1 && curr == 0) record_bin({cp, ".abandoned"});
        endfunction


        covergroup wr_cover_item with function sample(prim_wr_item_mon wr_item, int unsigned ratio);
            option.per_instance = 1;
            wr_occupancy : coverpoint wr_item.wdepth {
                option.comment = "CP-04: Write domain occupancy after every write transaction";
                bins one         = {1};
                bins half        = {PRIM_ASYNC_FIFO_DEPTH_P/2};
                bins almost_full = {PRIM_ASYNC_FIFO_DEPTH_P-1};
                bins full        = {PRIM_ASYNC_FIFO_DEPTH_P};
            }
            frecuency_relationships : coverpoint ratio {
                option.comment = "CP-10 FIFO frecuency relationships between domains.";
                bins rd_faster   = {[0:RATIO_RD_FASTER_MAX]};
                bins similar     = {[RATIO_SIMILAR_MIN:RATIO_SIMILAR_MAX]};
                bins wr_faster   = {[RATIO_WR_FASTER_MIN:$]};
            }

            // CP-12. Alcanzar una ocupacion es trivial; alcanzarla BAJO CADA
            // relacion de frecuencias es lo que ejercita el cruce de dominios.
            wr_occupancy_x_ratio : cross wr_occupancy, frecuency_relationships;
        endgroup

        covergroup cover_fifo_full_condition with function sample(int state, int unsigned ratio);
            option.per_instance = 1;
            fifo_full : coverpoint state {
                option.comment = "CP-06: FIFO full condition";
                bins reached   = (0 => 1);
                bins abandoned = (1 => 0);
            }
            frecuency_relationships : coverpoint ratio {
                option.comment = "CP-10 FIFO frecuency relationships between domains.";
                bins rd_faster   = {[0:RATIO_RD_FASTER_MAX]};
                bins similar     = {[RATIO_SIMILAR_MIN:RATIO_SIMILAR_MAX]};
                bins wr_faster   = {[RATIO_WR_FASTER_MIN:$]};
            }

            // CP-14. Llegar a lleno bajo cada relacion de frecuencias: es donde
            // la latencia de sincronizacion se manifiesta de forma distinta.
            full_x_ratio : cross fifo_full, frecuency_relationships;
        endgroup

        covergroup rd_cover_item with function sample(prim_rd_item_mon rd_item, int unsigned ratio);
            option.per_instance = 1;
            rd_occupancy : coverpoint rd_item.rdepth {
                option.comment = "CP-05: Read domain occupancy after every read transaction";
                bins empty       = {0};
                bins one         = {1};
                bins half        = {PRIM_ASYNC_FIFO_DEPTH_P/2};
                bins almost_full = {PRIM_ASYNC_FIFO_DEPTH_P-1};
            }
            frecuency_relationships : coverpoint ratio {
                option.comment = "CP-10 FIFO frecuency relationships between domains.";
                bins rd_faster   = {[0:RATIO_RD_FASTER_MAX]};
                bins similar     = {[RATIO_SIMILAR_MIN:RATIO_SIMILAR_MAX]};
                bins wr_faster   = {[RATIO_WR_FASTER_MIN:$]};
            }

            // CP-13. Simetrico de CP-12 sobre la vista del dominio de lectura.
            rd_occupancy_x_ratio : cross rd_occupancy, frecuency_relationships;
        endgroup


        covergroup cover_fifo_empty_condition with function sample(int state, int unsigned ratio);
            option.per_instance = 1;
            fifo_empty : coverpoint state {
                option.comment = "CP-07: FIFO empty condition";
                bins reached   = (0 => 1);
                bins abandoned = (1 => 0);
            }
            frecuency_relationships : coverpoint ratio {
                option.comment = "CP-10 FIFO frecuency relationships between domains.";
                bins rd_faster   = {[0:RATIO_RD_FASTER_MAX]};
                bins similar     = {[RATIO_SIMILAR_MIN:RATIO_SIMILAR_MAX]};
                bins wr_faster   = {[RATIO_WR_FASTER_MIN:$]};
            }

            // CP-15. Simetrico de CP-14. empty_rclk se calcula contra el puntero
            // de escritura sincronizado, igual que full_wclk contra el de lectura:
            // la latencia de sincronizacion se manifiesta en ambas condiciones.
            empty_x_ratio : cross fifo_empty, frecuency_relationships;
        endgroup

        covergroup cover_pointer_wrap with function sample(int value);
            option.per_instance = 1;
            fifo_pointer_wrap : coverpoint value {
                option.comment = "CP-08: FIFO internal pointers wrap condition";
                bins wr_wrap = {0};
                bins rd_wrap = {1};
            }
        endgroup

        covergroup cover_reset_occupancy with function sample(int unsigned occupancy);
            option.per_instance = 1;
            reset_occupancy : coverpoint occupancy {
                option.comment = "CP-09: FIFO occupancy when reset was asserted";
                bins while_empty   = {0};
                bins while_partial = {[1:PRIM_ASYNC_FIFO_DEPTH_P-1]};
                bins while_full    = {PRIM_ASYNC_FIFO_DEPTH_P};
            }
        endgroup

        // CP-11. Si la instrumentacion CDC de OpenTitan estaba activa en la
        // corrida. Es, como CP-10, una condicion de la CORRIDA y no del
        // estimulo: la fijan los flags de elaboracion y el plusarg, de modo que
        // se muestrea una sola vez. Cerrar sus dos bins exige que la campana
        // recorra las dos configuraciones, que es justamente lo que el plan
        // pide: la general sin instrumentacion y la pasada CDC con ella.
        covergroup cover_cdc_instrumentation with function sample(bit active);
            option.per_instance = 1;
            cdc_instrumentation : coverpoint active {
                option.comment = "CP-11: CDC instrumentation active during the run";
                bins disabled = {0};
                bins enabled  = {1};
            }
        endgroup

        covergroup cover_frecuency_relationships with function sample(int unsigned ratio);
            option.per_instance = 1;
            frecuency_relationships : coverpoint ratio {
                option.comment = "CP-10 FIFO frecuency relationships between domains.";
                bins rd_faster   = {[0:RATIO_RD_FASTER_MAX]};
                bins similar     = {[RATIO_SIMILAR_MIN:RATIO_SIMILAR_MAX]};
                bins wr_faster   = {[RATIO_WR_FASTER_MIN:$]};
            }
        endgroup

        function new(string name="", uvm_component parent);
            super.new(name, parent);

            
            wr_imp = new("wr_imp", this);
            rd_imp = new("rd_imp", this);
            reset_imp = new("reset_imp", this);

            wr_cover_item = new();
            rd_cover_item = new();
            wr_cover_item.set_inst_name($sformatf("%s_%s", get_full_name(),"wr_cover_item"));
            rd_cover_item.set_inst_name($sformatf("%s_%s", get_full_name(),"rd_cover_item"));

            cover_fifo_full_condition  = new();
            cover_fifo_empty_condition = new();
            cover_fifo_full_condition.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_fifo_full_condition"));
            cover_fifo_empty_condition.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_fifo_empty_condition"));

            cover_pointer_wrap = new ();
            cover_pointer_wrap.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_pointer_wrap"));

            cover_reset_occupancy = new();
            cover_reset_occupancy.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_reset_occupancy"));

            cover_cdc_instrumentation = new();
            cover_cdc_instrumentation.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_cdc_instrumentation"));

            cover_frecuency_relationships = new();
            cover_frecuency_relationships.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_frecuency_relationships"));

            // Predeclaracion de los bins que se contabilizan. El orden y los
            // nombres replican los de los covergroups de arriba; si alguno
            // cambia y este no, check_bin_bookkeeping() lo detecta.
            declare_bin("CP-04.one");        declare_bin("CP-04.half");
            declare_bin("CP-04.almost_full");declare_bin("CP-04.full");

            declare_bin("CP-05.empty");      declare_bin("CP-05.one");
            declare_bin("CP-05.half");       declare_bin("CP-05.almost_full");

            declare_bin("CP-06.reached");    declare_bin("CP-06.abandoned");
            declare_bin("CP-07.reached");    declare_bin("CP-07.abandoned");

            declare_bin("CP-08.wr_wrap");    declare_bin("CP-08.rd_wrap");

            declare_bin("CP-09.while_empty");declare_bin("CP-09.while_partial");
            declare_bin("CP-09.while_full");

            declare_bin("CP-10.rd_faster");  declare_bin("CP-10.similar");
            declare_bin("CP-10.wr_faster");
            declare_bin("CP-11.disabled");   declare_bin("CP-11.enabled");
        endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            
            if (!uvm_config_db#(real)::get(this, "", "wr_period_ns", wr_period_ns)) begin
                `uvm_fatal("COVERAGE_NO_PERIOD", "Could not get wr_period_ns from the config DB")
            end
            if (!uvm_config_db#(real)::get(this, "", "rd_period_ns", rd_period_ns)) begin
                `uvm_fatal("COVERAGE_NO_PERIOD", "Could not get rd_period_ns from the config DB")
            end

            ratio = (rd_period_ns / wr_period_ns)*100;
            cover_frecuency_relationships.sample(ratio);
            record_bin({"CP-10.", ratio_bin(ratio)});

            // CP-11. Las dos puertas del modulo de OpenTitan: el define, que se
            // resuelve al compilar, y el plusarg, en ejecucion. Hacen falta las
            // dos, de modo que se comprueban las dos.
            begin
                bit cdc_on = 1'b0;
                `ifdef SIMULATION
                    bit [31:0] pa;
                    if ($value$plusargs("cdc_instrumentation_enabled=%d", pa)) begin
                        cdc_on = (pa != 0);
                    end
                `endif
                cover_cdc_instrumentation.sample(cdc_on);
                record_bin(cdc_on ? "CP-11.enabled" : "CP-11.disabled");
            end

            // La clase que etiqueta el volcado debe ser la MEDIDA, no la que
            // el test pidio. Un test que no restringe la relacion corre con
            // una concreta, y etiquetarla 'any' la convertia en una cuarta
            // clase inexistente al derivar los cruces: 48 bins en vez de 36.
            uvm_config_db #(string)::set(null, "*", "cov_class", ratio_bin(ratio));
        endfunction


        virtual function string coverage2string();
            string result = {
                //"CP-04: Write domain occupancy after every write transaction"
                $sformatf("\nCP-04: Write domain occupancy after every write transaction: %03.2f%%", wr_cover_item.wr_occupancy.get_inst_coverage()),
                //"CP-05: Read domain occupancy after every read transaction"
                $sformatf("\nCP-05: Read domain occupancy after every read transaction: %03.2f%%", rd_cover_item.rd_occupancy.get_inst_coverage()),
                //"CP-06: FIFO full condition"
                $sformatf("\nCP-06: FIFO full condition: %03.2f%%",  cover_fifo_full_condition.fifo_full.get_inst_coverage()),
                //"CP-07: FIFO empty condition"
                $sformatf("\nCP-07: FIFO empty condition: %03.2f%%", cover_fifo_empty_condition.fifo_empty.get_inst_coverage()),
                //"CP-08: FIFO internal pointers wrap condition"
                $sformatf("\nCP-08: FIFO internal pointers wrap condition: %03.2f%%", cover_pointer_wrap.fifo_pointer_wrap.get_inst_coverage()),
                //"CP-09: FIFO occupancy when reset was asserted"
                $sformatf("\nCP-09: FIFO occupancy when reset was asserted: %03.2f%%", cover_reset_occupancy.reset_occupancy.get_inst_coverage()),
                //CP-10 FIFO frecuency relationships between domains.
                $sformatf("\nCP-10: FIFO frecuency relationships between domains: %03.2f%%", cover_frecuency_relationships.frecuency_relationships.get_inst_coverage()),
                $sformatf("\nCP-11: CDC instrumentation active during the run: %03.2f%%", cover_cdc_instrumentation.cdc_instrumentation.get_inst_coverage()),
                //"CP-12: Write domain occupancy x frecuency relationships"
                $sformatf("\nCP-12: Write domain occupancy x frecuency relationships: %03.2f%%", wr_cover_item.wr_occupancy_x_ratio.get_inst_coverage()),
                //"CP-13: Read domain occupancy x frecuency relationships"
                $sformatf("\nCP-13: Read domain occupancy x frecuency relationships: %03.2f%%", rd_cover_item.rd_occupancy_x_ratio.get_inst_coverage()),
                //"CP-14: FIFO full condition x frecuency relationships"
                $sformatf("\nCP-14: FIFO full condition x frecuency relationships: %03.2f%%", cover_fifo_full_condition.full_x_ratio.get_inst_coverage()),
                //"CP-15: FIFO empty condition x frecuency relationships"
                $sformatf("\nCP-15: FIFO empty condition x frecuency relationships: %03.2f%%", cover_fifo_empty_condition.empty_x_ratio.get_inst_coverage())
                
            };
            return result;
        endfunction

        virtual function void write_reset(int unsigned occupancy);
            cover_reset_occupancy.sample(occupancy);

            if (occupancy == 0)                            record_bin("CP-09.while_empty");
            else if (occupancy < PRIM_ASYNC_FIFO_DEPTH_P)   record_bin("CP-09.while_partial");
            else                                           record_bin("CP-09.while_full");
        endfunction


        virtual function void write_wr(prim_wr_item_mon item);
            int full_state;
            string b;

            wr_cover_item.sample(item, ratio);
            full_state = (item.wdepth == PRIM_ASYNC_FIFO_DEPTH_P) ? 1 : 0;
            cover_fifo_full_condition.sample(full_state, ratio);

            // CP-04: la vista de escritura no tiene bin 'empty' (3.4.1).
            b = occupancy_bin(item.wdepth);
            if (b != "" && b != "empty") record_bin({"CP-04.", b});

            // CP-06
            record_transition("CP-06", prev_full_state, full_state);
            prev_full_state = full_state;

            wr_accepted_count++;
            if (wr_accepted_count == PRIM_ASYNC_FIFO_DEPTH_P) begin
                wr_accepted_count = 0;
                cover_pointer_wrap.sample(0);
                record_bin("CP-08.wr_wrap");
            end

            if(env_config != null && env_config.get_has_recording()) begin
                `uvm_info("DEBUG", $sformatf("Coverage: %0s", coverage2string()),UVM_NONE)
            end
        endfunction

        virtual function void write_rd(prim_rd_item_mon item);
            int empty_state;
            string b;

            rd_cover_item.sample(item, ratio);
            empty_state = (item.rdepth == 0) ? 1 : 0;
            cover_fifo_empty_condition.sample(empty_state, ratio);

            // CP-05: la vista de lectura no tiene bin 'full' (3.4.1).
            b = occupancy_bin(item.rdepth);
            if (b != "" && b != "full") record_bin({"CP-05.", b});

            // CP-07
            record_transition("CP-07", prev_empty_state, empty_state);
            prev_empty_state = empty_state;

            rd_accepted_count++;
            if (rd_accepted_count == PRIM_ASYNC_FIFO_DEPTH_P) begin
                rd_accepted_count = 0;
                cover_pointer_wrap.sample(1);
                record_bin("CP-08.rd_wrap");
            end

            if(env_config != null && env_config.get_has_recording()) begin
                `uvm_info("DEBUG", $sformatf("Coverage: %0s", coverage2string()),UVM_NONE)
            end
        endfunction

        // -------------------------------------------------------------------
        // Comprobacion cruzada contra el covergroup.
        //
        // La contabilidad por bin duplica la clasificacion que el covergroup hace
        // por dentro. Aqui se comprueba que las dos coinciden: el porcentaje
        // derivado de los contadores debe igualar el que reporta el covergroup.
        // Si discrepan, uno de los dos miente y la corrida falla.
        //
        // Va en check_phase porque ES una comprobacion, no un informe.
        // -------------------------------------------------------------------
        virtual function void extract_phase(uvm_phase phase);
            super.extract_phase(phase);
            dump_bins("env");
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            check_bin_bookkeeping("CP-04", wr_cover_item.wr_occupancy.get_inst_coverage());
            check_bin_bookkeeping("CP-05", rd_cover_item.rd_occupancy.get_inst_coverage());
            check_bin_bookkeeping("CP-06", cover_fifo_full_condition.fifo_full.get_inst_coverage());
            check_bin_bookkeeping("CP-07", cover_fifo_empty_condition.fifo_empty.get_inst_coverage());
            check_bin_bookkeeping("CP-08", cover_pointer_wrap.fifo_pointer_wrap.get_inst_coverage());
            check_bin_bookkeeping("CP-09", cover_reset_occupancy.reset_occupancy.get_inst_coverage());
            check_bin_bookkeeping("CP-10", cover_frecuency_relationships.frecuency_relationships.get_inst_coverage());
            check_bin_bookkeeping("CP-11", cover_cdc_instrumentation.cdc_instrumentation.get_inst_coverage());
        endfunction


        // El informe va en report_phase y no en check_phase a proposito:
        // check_phase queda libre para el criterio de aprobado de la tarea 7.6,
        // que es un uvm_error condicional y no un informe.
        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COVERAGE", $sformatf("Enviroment: %0s", coverage2string()),UVM_NONE)
            
        endfunction

        virtual function void handle_reset(uvm_phase phase);
            cover_fifo_full_condition.sample(COND_RESET_BOUNDARY, ratio);
            cover_fifo_empty_condition.sample(COND_RESET_BOUNDARY, ratio);

            // Misma rotura de la cadena en la contabilidad paralela.
            prev_full_state  = COND_RESET_BOUNDARY;
            prev_empty_state = COND_RESET_BOUNDARY;
            wr_accepted_count = 0;
            rd_accepted_count = 0;
        endfunction  

    endclass

`endif