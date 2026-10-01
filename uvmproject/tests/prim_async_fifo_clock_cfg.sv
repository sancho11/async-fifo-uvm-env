`ifndef PRIM_ASYNC_FIFO_CLOCK_CFG_SV
    `define PRIM_ASYNC_FIFO_CLOCK_CFG_SV

    // Clase de relacion de frecuencias que un test quiere ejercitar.
    // Se corresponde una a una con los bins de CP-10.
    typedef enum {
        RATIO_ANY,        // sin restringir: el comportamiento por defecto
        RATIO_WR_FASTER,  // el periodo de lectura es mayor -> escritura mas rapida
        RATIO_SIMILAR,
        RATIO_RD_FASTER
    } prim_async_fifo_ratio_class_e;

    // Geometria temporal de una corrida.
    //
    // POR QUE DECIMAS DE NANOSEGUNDO Y NO 'real':
    // SystemVerilog no permite 'rand real' -la randomizacion con restricciones
    // solo opera sobre tipos integrales-, de modo que la relacion entre periodos
    // no puede expresarse como restriccion sobre nanosegundos. Se randomizan
    // decimas como enteros y se convierte al final. Todas las restricciones de
    // abajo son lineales sobre enteros, que es justo lo que el solver resuelve
    // bien.
    class prim_async_fifo_clock_cfg extends uvm_object;

        rand int unsigned wr_tenths;
        rand int unsigned rd_tenths;

        // No es rand: lo fija el test antes de randomizar.
        prim_async_fifo_ratio_class_e target = RATIO_ANY;

        `uvm_object_utils(prim_async_fifo_clock_cfg)

        function new(string name = "prim_async_fifo_clock_cfg");
            super.new(name);
        endfunction

        // 8,0 .. 20,0 ns. El rango se elige para que el cociente rd/wr pueda
        // recorrer las tres clases de CP-10: de 0,4 a 2,5.
        constraint c_range {
            wr_tenths inside {[80:200]};
            rd_tenths inside {[80:200]};
        }

        // Clasificacion sobre el mismo cociente que mide CP-10, expresado en
        // centesimas: pct = 100 * rd / wr.
        //
        // LOS MARGENES SON DELIBERADOS. Los bins de CP-10 cortan en 89/90 y
        // 110/111, pero el componente de cobertura calcula el cociente en coma
        // flotante y lo REDONDEA al asignarlo a un entero, mientras que aqui se
        // resuelve en aritmetica entera exacta. Son dos calculos independientes
        // del mismo numero, y en la frontera pueden discrepar en una unidad.
        // Dejando margen -88 en vez de 89, 112 en vez de 111- una discrepancia
        // de redondeo no puede colocar la corrida en un bin distinto del que el
        // test pidio. El coste es una franja estrecha inalcanzable; la
        // alternativa es un fallo intermitente e irreproducible.
        constraint c_ratio_class {
            (target == RATIO_RD_FASTER) -> 100 * rd_tenths <=  88 * wr_tenths;
            (target == RATIO_SIMILAR)   -> (100 * rd_tenths >=  92 * wr_tenths &&
                                            100 * rd_tenths <= 108 * wr_tenths);
            (target == RATIO_WR_FASTER) -> 100 * rd_tenths >= 112 * wr_tenths;
        }

        // Comprobacion defensiva de lo que el solver acaba de producir.
        //
        // No deberia hacer falta: si las restricciones de arriba se aplican,
        // esto se cumple por construccion. Existe porque se observo una corrida
        // -no reproducida despues- en la que randomize() devolvio EXITO con
        // valores de 32 bits en crudo, fuera de rango y violando la clase
        // pedida. Un resultado asi es indetectable aguas abajo: la simulacion
        // corre, la cobertura clasifica sobre el cociente equivocado y nada
        // avisa. El coste de la comprobacion es nulo; el de no tenerla, una
        // regresion entera de numeros sin valor.
        function void post_randomize();
            int unsigned pct;

            if (!(wr_tenths inside {[80:200]}) || !(rd_tenths inside {[80:200]})) begin
                `uvm_fatal("CLOCK_CFG",
                           $sformatf({"The solver produced out-of-range periods: ",
                                      "wr_tenths=%0d rd_tenths=%0d (expected 80..200). ",
                                      "The constraints were not applied. ",
                                      "If the values look like raw 32-bit randoms, the snapshot is ",
                                      "most likely stale: rebuild with 'make compile elab' before running."},
                                     wr_tenths, rd_tenths))
            end

            // Misma aritmetica que usa el componente de cobertura para CP-10.
            pct = int'((rd_period_ns() / wr_period_ns()) * 100.0);

            case (target)
                RATIO_RD_FASTER: if (pct > 89)  clock_class_error(pct, "< 90");
                RATIO_SIMILAR:   if (pct < 90 || pct > 110) clock_class_error(pct, "90..110");
                RATIO_WR_FASTER: if (pct < 111) clock_class_error(pct, "> 110");
                default: ; // RATIO_ANY no impone nada
            endcase
        endfunction

        protected function void clock_class_error(int unsigned pct, string expected);
            `uvm_fatal("CLOCK_CFG",
                       $sformatf({"The generated geometry does not belong to the requested class: ",
                                  "%0s yields a ratio of %0d hundredths, expected %0s."},
                                 target.name(), pct, expected))
        endfunction

        function real wr_period_ns();
            return real'(wr_tenths) / 10.0;
        endfunction

        function real rd_period_ns();
            return real'(rd_tenths) / 10.0;
        endfunction

        virtual function string convert2string();
            return $sformatf("wr=%0.1f ns, rd=%0.1f ns, ratio=%0.3f, class=%0s",
                             wr_period_ns(), rd_period_ns(),
                             rd_period_ns() / wr_period_ns(), target.name());
        endfunction

    endclass
`endif
