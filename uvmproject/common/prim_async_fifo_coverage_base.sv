`ifndef PRIM_ASYNC_FIFO_COVERAGE_BASE_SV
    `define PRIM_ASYNC_FIFO_COVERAGE_BASE_SV

    // Base comun de los tres componentes de cobertura: los dos de agente y el
    // del entorno.
    //
    // POR QUE EXISTE: SystemVerilog no ofrece ninguna API para enumerar los bins
    // de un covergroup ni sus aciertos. get_inst_coverage() devuelve un
    // porcentaje, y un 75 % dice que falta uno de cuatro sin decir CUAL. El
    // criterio de aprobado necesita lo segundo. La via del simulador esta
    // cerrada: xcrg exige licencia PRO.
    //
    // La solucion es llevar la cuenta en paralelo, lo que duplica la
    // clasificacion que el covergroup hace por dentro. Esa duplicacion es el
    // riesgo real -las dos clasificaciones pueden divergir sin que nadie lo
    // note-, y por eso check_bin_bookkeeping() compara en CADA corrida el
    // porcentaje derivado de estos contadores con el que reporta el covergroup.
    // Si discrepan, la corrida falla. La duplicacion queda verificada en lugar
    // de supuesta.
    virtual class prim_async_fifo_coverage_base extends uvm_component;

        // Clave: "<CP>.<bin>". Se PREDECLARA completo, de modo que un bin sin
        // aciertos aparezca en el informe como cero y no como ausente: es la
        // diferencia entre "no se alcanzo" y "nadie lo midio", y sin los ceros el
        // consolidador se queda sin denominador.
        protected int unsigned bin_hits[string];

        function new(string name = "", uvm_component parent);
            super.new(name, parent);
        endfunction

        protected function void declare_bin(string key);
            bin_hits[key] = 0;
        endfunction

        protected function void record_bin(string key);
            if (!bin_hits.exists(key)) begin
                `uvm_fatal("COV_BOOKKEEPING",
                           $sformatf("Bin '%0s' is not declared: the key is misspelled or a declare_bin() is missing", key))
            end
            bin_hits[key]++;
        endfunction

        // Cuantos bins de un punto existen y cuantos tienen algun acierto.
        protected function void bin_summary(string cp,
                                           output int unsigned n_total,
                                           output int unsigned n_hit);
            string prefix = {cp, "."};
            n_total = 0;
            n_hit   = 0;
            foreach (bin_hits[key]) begin
                if (key.substr(0, prefix.len()-1) == prefix) begin
                    n_total++;
                    if (bin_hits[key] > 0) n_hit++;
                end
            end
        endfunction

        // Clasificadores compartidos: el espaciado entre transacciones (CP-01,
        // CP-02) y el estado del bus en el reset (CP-03) tienen los mismos bins
        // en los dos agentes.
        protected function string spacing_bin(int unsigned delay);
            if (delay == 0) return "back_to_back";
            if (delay <= 3) return "short_gap";
            return "long_gap";
        endfunction

        protected function string bus_state_bin(bit transfer_ongoing);
            return transfer_ongoing ? "during_transfer" : "during_idle";
        endfunction

        // -------------------------------------------------------------------
        // Volcado por bin. Cada componente escribe su PROPIO fichero, con su
        // etiqueta como sufijo: tres componentes escribiendo el mismo fichero
        // dependeria del orden de extract_phase, que UVM no garantiza entre
        // hermanos, y el primero en abrir en modo 'w' borraria a los demas.
        //
        // El consolidador los recoge todos con un glob, de modo que repartirlos
        // no cuesta nada aguas abajo.
        // -------------------------------------------------------------------
        protected function void dump_bins(string label);
            int    fd;
            string prefix    = "results/cov";
            string test_name  = "unknown";
            string cov_class  = "unknown";
            string seed       = "unknown";
            string path;
            string point;
            string bin_name;
            int    idx;

            void'($value$plusargs("COV_CSV=%s",   prefix));
            void'($value$plusargs("COV_TEST=%s",  test_name));
            // Prioridad: lo que el test resolvio de verdad; el plusarg solo
            // como respaldo para bancos que no usen el test base.
            if (!uvm_config_db #(string)::get(null, "*", "cov_class", cov_class)) begin
                void'($value$plusargs("COV_CLASS=%s", cov_class));
            end
            void'($value$plusargs("COV_SEED=%s",  seed));
            path = {prefix, "_", label, ".csv"};

            fd = $fopen(path, "w");
            if (fd == 0) begin
                `uvm_warning("COV_CSV", $sformatf("Could not open %0s for writing", path))
                return;
            end

            // La CLASE de relacion de frecuencias va en columna propia y no
            // enterrada en una etiqueta: es lo que permite derivar los cruces
            // CP-11 a CP-14 al consolidar, sin tener que contarlos aqui.
            $fdisplay(fd, "test,class,seed,coverpoint,bin,hits");
            foreach (bin_hits[key]) begin
                idx = -1;
                for (int i = 0; i < key.len(); i++) begin
                    if (key.getc(i) == 46) idx = i;   // '.'
                end
                point    = key.substr(0, idx-1);
                bin_name = key.substr(idx+1, key.len()-1);
                $fdisplay(fd, "%0s,%0s,%0s,%0s,%0s,%0d",
                          test_name, cov_class, seed, point, bin_name, bin_hits[key]);
            end
            $fclose(fd);

            `uvm_info("COV_CSV", $sformatf("Dumped %0d bins to %0s", bin_hits.size(), path), UVM_LOW)
        endfunction

        // Comprobacion cruzada contra el covergroup. Va en check_phase porque ES
        // una comprobacion, no un informe.
        protected function void check_bin_bookkeeping(string cp, real cg_percent);
            int unsigned n_total;
            int unsigned n_hit;
            real         derived;

            bin_summary(cp, n_total, n_hit);
            if (n_total == 0) begin
                `uvm_error("COV_BOOKKEEPING", $sformatf("%0s has no declared bins", cp))
                return;
            end

            derived = (100.0 * real'(n_hit)) / real'(n_total);

            // Tolerancia de 0,1 puntos: el covergroup reporta 66.67 y la division
            // exacta da 66.666..., que no es una discrepancia real.
            if ((derived - cg_percent > 0.1) || (cg_percent - derived > 0.1)) begin
                `uvm_error("COV_BOOKKEEPING",
                           $sformatf({"%0s: per-bin bookkeeping reports %0.2f%% (%0d of %0d bins) ",
                                      "while the covergroup reports %0.2f%%. The two classifications have ",
                                      "diverged: check that the declared bins match the covergroup bins."},
                                     cp, derived, n_hit, n_total, cg_percent))
            end
        endfunction

    endclass
`endif
