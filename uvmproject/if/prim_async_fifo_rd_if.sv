`ifndef PRIM_ASYNC_FIFO_RD_IF_SV
    `define PRIM_ASYNC_FIFO_RD_IF_SV

    interface prim_async_fifo_rd_if#(
        parameter int unsigned PRIM_ASYNC_FIFO_DEPTH = 4,
        parameter int unsigned PRIM_ASYNC_FIFO_DEPTH_WIDTH = 3,
        parameter int unsigned PRIM_ASYNC_FIFO_DATA_WIDTH = 16
    )(input clk_rd_i);
        //Señales físicas
        logic                             rst_rd_ni = 0;
        // rready_drv es lo que el AGENTE pide; rready_i es el CABLE que llega al
        // DUT. La separacion replica la del lado de escritura y no es cosmetica:
        // el driver necesita conducir la señal y ademas leerla para detectar que
        // su peticion llego al cable. Con un unico 'logic' haciendo los dos
        // papeles hay que declararlo 'inout' en el clocking block, y entonces el
        // cb muestrea -con skew de entrada #1step- una variable que el mismo cb
        // conduce -con skew de salida #1ns-. Medido: mon_cb devolvia X en el
        // instante del reset, lo que dejaba CP-03b sin poder registrar
        // 'during_transfer'.
        //
        // A diferencia de wvalid_i, rready_i NO se gatea con el reset: PROP-06
        // establece que rready_i es un PERMISO y mantenerlo activo es legitimo.
        logic                             rready_drv = 0;
        wire                              rready_i;
        assign rready_i = rready_drv;
        logic                             rvalid_o;
        logic [PRIM_ASYNC_FIFO_DATA_WIDTH-1:0]  rdata_o;
        logic [PRIM_ASYNC_FIFO_DEPTH_WIDTH-1:0] rdepth_o;

        //XSIM no puede inferir el reloj por lo que es necesario especificarlo (No necesario en DSIM)
        default clocking cb @(posedge clk_rd_i); endclocking

        //Clocking Blocks para cada UVM component que lo necesita.
        clocking drv_cb @(posedge clk_rd_i);
            default input #1step output #1ns; //1step lee justo el estado antes del flanco de reloj
            output rready_drv;
            input  rready_i;   // el cable, para detectar que la peticion llego
            input rdata_o;
            input rdepth_o;
            input rvalid_o;
        endclocking

        clocking mon_cb @(posedge clk_rd_i);
            default input #1step;
            input rready_i;
            input rdata_o;
            input rdepth_o;
            input rvalid_o;
        endclocking

        //Metodos de interface (Para exportar junto con los modports)
        function automatic void drive_idle();
            drv_cb.rready_drv <= 1'b0;
        endfunction

        function automatic void reset_assert();
            rst_rd_ni <= 1'b0; // Assertion del reset es asincrono.
        endfunction

        task automatic reset_deassert();
            @(posedge clk_rd_i)
            rst_rd_ni <= 1'b1; // Deassertion del reset es asincrono.
        endtask

        task automatic do_reset(int unsigned n_cycles = 5);
            reset_assert();
            drive_idle();
            if (n_cycles>1) begin
                repeat (n_cycles-1) @(posedge clk_rd_i);
            end
            reset_deassert();
        endtask

        task automatic wait_reset_start();
            if(rst_rd_ni !==0) begin
                @(negedge rst_rd_ni);
            end
        endtask

        task automatic wait_reset_end();
            while(rst_rd_ni !== 1) begin
                @(posedge clk_rd_i);
            end
        endtask

        //Modports
        //DUT (Documentacion, no realmente implementable)
        modport dut (
            input  clk_rd_i,
            input  rst_rd_ni,
            input  rready_i,
            output rdata_o,
            output rdepth_o,
            output rvalid_o
        );

        //Modport del driver (Conjunto de reglas de lo que puede y
        // no hacer así como la forma en la que tiene que hacerlo)
        modport drv(
            clocking drv_cb,
            input  clk_rd_i,
            output rst_rd_ni,
            import function void drive_idle(),
            import function void reset_assert(),
            import task reset_deassert(),
            import task do_reset(int unsigned n_cycles),
            import task wait_reset_start(),
            import task wait_reset_end()
        );

        //Modport del monitor.
        modport mon(
            clocking mon_cb,
            input clk_rd_i,
            input rst_rd_ni,
            import task wait_reset_start(),
            import task wait_reset_end()
        );


        //SVA para la verificación de señales de lectura
        bit has_checks = 1;

        // Contador de fallos de asercion de esta interfaz.
        //
        // POR QUE UN CONTADOR Y NO UN INFORME DE UVM: las aserciones emiten
        // $error, que NO incrementa UVM_ERROR. La decision de no encaminarlas al
        // sistema de reporte de UVM es deliberada -obligaria a esta interfaz a
        // importar uvm_pkg, y debe seguir sirviendo en bancos sin UVM y en un
        // eventual flujo formal-, pero deja un agujero: una corrida con
        // aserciones disparando termina con "UVM_ERROR: 0".
        //
        // Un entero no obliga a importar nada y cierra el agujero: el test base
        // lo lee por la interfaz virtual para emitir su veredicto, y los tests de
        // inyeccion de fallos lo usan para comprobar que la asercion disparo.
        int unsigned assert_fail_count = 0;
        
        //Señalización y comportamiento en condición de lleno
        //sequence fifo_is_full;  //No se usa en esta interfaz
        //    (rdepth_o == PRIM_ASYNC_FIFO_DEPTH);
        //endsequence

        sequence fifo_is_empty;
            (rdepth_o == 0);
        endsequence

        sequence read_is_blocked;
            (rvalid_o && !rready_i);
        endsequence
        
        //Implementacion de propiedades que puedan validarse como SVA
        
        // INTEGRIDAD DE DATOS
        // PROP-01. N/A (Pertenece al Scoreboard)
        // PROP-02. N/A (Pertenece al Scoreboard)
        // PROP-03. N/A (Pertenece al Scoreboard)
        
        //PROTOCOLO DE INTERFAZ
        // PROP-04. Una vez que `rvalid_o` está activo, permanece activo
        // hasta que se confirma la transferencia.
        property rvalid_o_stable_until_read_is_successful;
            @(posedge clk_rd_i) disable iff(!rst_rd_ni || !has_checks)
            read_is_blocked |=> rvalid_o == 1;
        endproperty
        PROP04_RVALID_STABLE_A : assert property(rvalid_o_stable_until_read_is_successful) else begin
            assert_fail_count++;
            $error("PROP-04: rvalid_o dropped before the transfer completed");
        end

        // PROP-05. Una vez que `rvalid_o` está activo, el dato en `rdata_o`
        // permanece activo hasta que se confirma la transferencia.
        property rdata_o_stable_until_read_is_successful;
            @(posedge clk_rd_i) disable iff(!rst_rd_ni || !has_checks)
            read_is_blocked |=> $stable(rdata_o);//$past(rdata_o) == rdata_o;
        endproperty
        PROP05_RDATA_STABLE_A : assert property(rdata_o_stable_until_read_is_successful) else begin
            assert_fail_count++;
            $error("PROP-05: rdata_o changed while the transfer was blocked");
        end


        // PROP-06. Inactividad durante reset. No se produce ninguna transferencia
        // mientras el reset del dominio está activo.
        // C:
        property no_transfers_while_reset_is_active_c;
            @(posedge clk_rd_i) disable iff(!has_checks)
            //La transferencia se registra por el handshake de rvalid_o == 1 y rready_i == 1
            // por tanto el DUT no debe hacer assert de rvalid_o durante el reset
            (rst_rd_ni==0) |-> (rvalid_o==0);
        endproperty
        PROP06C_NO_VALID_DURING_RESET_A : assert property(no_transfers_while_reset_is_active_c) else begin
            assert_fail_count++;
            $error("PROP-06c: rvalid_o asserted while the read reset was active");
        end
        // D:
        property no_transfers_while_reset_is_active_d;
            @(posedge clk_rd_i) disable iff(!has_checks)
            //Durante el reset el DUT no debe alterar su estado observable y permanecer en 0
            (rst_rd_ni==0) |-> (rdepth_o==0);
        endproperty
        PROP06D_DEPTH_ZERO_DURING_RESET_A : assert property(no_transfers_while_reset_is_active_d) else begin
            assert_fail_count++;
            $error("PROP-06d: rdepth_o non-zero while the read reset was active");
        end


        //CRUCE DE DOMINIOS
        // PROP-07. N/A (Pertenece al Scoreboard)
        // PROP-08. ‘rdepth_o‘ no excede ‘Depth‘.
        property rdepth_o_is_leq_depth;
            @(posedge clk_rd_i) disable iff(!rst_rd_ni || !has_checks)
            (rdepth_o <= PRIM_ASYNC_FIFO_DEPTH);
        endproperty
        PROP08_RDEPTH_LEQ_DEPTH_A: assert property(rdepth_o_is_leq_depth) else begin
            assert_fail_count++;
            $error("PROP-08: rdepth_o exceeded Depth");
        end

        // PROP-09. N/A (Pertenece al Scoreboard)

        //CONDICIONES LIMITE
        // PROP-10. (Pertenece a la interface de escritura)
        // PROP-11. Bloqueo por vacío. `rvalid_o` está inactivo cuando el FIFO está vacío
        // según la visión del dominio de lectura.
        property no_valid_reads_while_rdepth_o_is_empty;
            @(posedge clk_rd_i) disable iff(!rst_rd_ni || !has_checks)
            fifo_is_empty |-> (rvalid_o==0);
        endproperty
        PROP11_NO_VALID_WHEN_EMPTY_A : assert property(no_valid_reads_while_rdepth_o_is_empty) else begin
            assert_fail_count++;
            $error("PROP-11: rvalid_o asserted while the FIFO reports empty");
        end
        // PROP-12. N/A (Pertenece al Scoreboard)
        // PROP-13. La liberacion del reset debe coincidir con un flanco de clk_rd_i.

        // realtime, NO time: 'time' es integral y redondearia el instante del flanco.
        // Con periodos enteros el redondeo es invisible; con periodos randomizados
        // los flancos caen en fracciones de ns y la comparacion falla, produciendo
        // un falso positivo de PROP-13 en cada liberacion de reset.
        realtime last_rd_clk_edge = 0;
        always @(posedge clk_rd_i) last_rd_clk_edge = $realtime;

        always @(posedge rst_rd_ni) begin
            if (has_checks && $realtime != last_rd_clk_edge) begin
                assert_fail_count++;
                $error("PROP-13: rst_rd_ni was deasserted off a clk_rd_i edge");
            end
        end

    endinterface

`endif