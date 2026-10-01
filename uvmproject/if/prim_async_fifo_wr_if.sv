`ifndef PRIM_ASYNC_FIFO_WR_IF_SV
    `define PRIM_ASYNC_FIFO_WR_IF_SV

    // ---------------------------------------------------------------------------
    // Interface del dominio de ESCRITURA de prim_fifo_async.
    //
    // Quien la usa y para qué:
    //   - el DUT   : recibe wvalid_i/wdata_i, produce wready_o/wdepth_o
    //   - el driver: conduce wvalid_i/wdata_i, observa wready_o
    //   - el monitor: observa todo, no conduce nada
    // Cada uno de esos tres papeles tiene su modport al final del archivo.
    // ---------------------------------------------------------------------------
    interface prim_async_fifo_wr_if#(
        parameter int unsigned PRIM_ASYNC_FIFO_DEPTH = 4,
        parameter int unsigned PRIM_ASYNC_FIFO_DEPTH_WIDTH = 3,
        parameter int unsigned PRIM_ASYNC_FIFO_DATA_WIDTH = 16
    )(input clk_wr_i);
        // -------------------------------------------------------------------
        // Señales físicas. Sin dirección: los modports se la ponen.
        // -------------------------------------------------------------------
        logic                             rst_wr_ni = 0;
        logic                             wvalid_drv = 0; //Señal para respetar los cb
        logic                             wvalid_i;
        logic                             wready_o;
        logic [PRIM_ASYNC_FIFO_DATA_WIDTH-1:0]  wdata_i;
        logic [PRIM_ASYNC_FIFO_DEPTH_WIDTH-1:0] wdepth_o;

        //Al usar clocking blocks no podemos cambiar el valor de las señales de forma
        // asincrona como si lo puede hacer el reset que no pertenece a ningun cb.
        // Esta asignación nos permite reaccionar de forma asincrona al reset, al mismo
        // tiempo que mantenemos el uso del clocking block. De forma que aseguramos la
        // PROP-06, al mismo tiempo que conservamos las ventajas de usar el clocking block.
        assign wvalid_i = rst_wr_ni ? wvalid_drv: 0;

        // -------------------------------------------------------------------
        // Clocking block por defecto.
        // XSim no infiere el reloj de las aserciones, hay que dárselo (no es
        // necesario en DSIM). Va vacío: solo aporta el reloj implícito para
        // $past/$rose/$stable en las propiedades de la tarea 2.4.
        // -------------------------------------------------------------------
        default clocking cb @(posedge clk_wr_i); endclocking

        // -------------------------------------------------------------------
        // Clocking block del DRIVER.
        //
        //   input  #1step : muestrea en la región Preponed, es decir el valor
        //                   ESTABLE justo antes del flanco. Así el driver nunca
        //                   ve el valor nuevo que el DUT acaba de calcular en
        //                   ese mismo flanco: elimina la carrera driver/DUT.
        //   output #1ns   : conduce 1 ns DESPUÉS del flanco. El DUT muestrea en
        //                   el flanco, así que ve el valor anterior; el cambio
        //                   se ve claramente separado en la onda.
        //
        // Las direcciones son desde el punto de vista del DRIVER: conduce
        // wvalid_i/wdata_i (output) y observa wready_o/wdepth_o (input).
        // -------------------------------------------------------------------
        clocking drv_cb @(posedge clk_wr_i);
            default input #1step output #1ns;
            output wvalid_drv;
            output wdata_i;
            input  wvalid_i; // ← el pin, para detectar el handshake real
            input  wready_o;
            input  wdepth_o;
        endclocking

        // -------------------------------------------------------------------
        // Clocking block del MONITOR.
        // Todo input, incluidas las señales que el driver conduce. Un monitor
        // que intente escribir a través de mon_cb no compila: esa es la
        // garantía que buscamos.
        // -------------------------------------------------------------------
        clocking mon_cb @(posedge clk_wr_i);
            default input #1step;
            input wvalid_i;
            input wdata_i;
            input wready_o;
            input wdepth_o;
        endclocking

        // -------------------------------------------------------------------
        // Métodos de la interface.
        // Se exponen a los modports con `import task`. Ventaja: la secuencia de
        // flancos del reset vive en un solo sitio, no duplicada en cada test.
        //
        // rst_wr_ni NO entra en ningún clocking block: es asíncrono a propósito
        // (queremos poder afirmarlo y liberarlo fuera de flanco).
        // -------------------------------------------------------------------
        function automatic void drive_idle();
            drv_cb.wvalid_drv <= 1'b0;
            drv_cb.wdata_i  <= 'b0;
        endfunction

        function automatic void reset_assert();
            rst_wr_ni <= 1'b0; // Assertion del reset es asincrono.
        endfunction

        task automatic reset_deassert();
            @(posedge clk_wr_i)
            rst_wr_ni <= 1'b1; // Deassertion del reset es asincrono.
        endtask

        task automatic do_reset(int unsigned n_cycles = 5);
            reset_assert();
            drive_idle();
            if (n_cycles>1) begin
                repeat (n_cycles-1) @(posedge clk_wr_i);
            end
            reset_deassert();
        endtask

        task automatic wait_reset_start();
            if(rst_wr_ni !==0) begin
                @(negedge rst_wr_ni);
            end
        endtask

        task automatic wait_reset_end();
            while(rst_wr_ni !== 1) begin
                @(posedge clk_wr_i);
            end
        endtask


        // -------------------------------------------------------------------
        // MODPORTS. Cada uno es una vista de las señales de arriba, con las
        // direcciones vistas DESDE QUIEN LO USA (no desde la interface).
        // -------------------------------------------------------------------

        // Vista del DUT. prim_fifo_async tiene puertos escalares, no un puerto
        // de interface, así que este modport no se puede conectar directamente
        // y queda como documentación de direcciones. Se declara igual: evita
        // volver al RTL de OpenTitan cada vez que dudes de un sentido.
        modport dut (
            input  clk_wr_i,
            input  rst_wr_ni,
            input  wvalid_i,
            input  wdata_i,
            output wready_o,
            output wdepth_o
        );

        // Vista del DRIVER: la ventana temporal es drv_cb; el reloj y el reset
        // se exponen crudos porque viven fuera del clocking block.
        modport drv (
            clocking drv_cb,
            input    clk_wr_i,
            output   rst_wr_ni,
            import   function void drive_idle(),
            import   function void reset_assert(),
            import   task reset_deassert(),
            import   task do_reset(int unsigned n_cycles),
            import   task wait_reset_start(),
            import   task wait_reset_end()
        );

        // Vista del MONITOR: ventana mon_cb, todo de lectura.
        modport mon (
            clocking mon_cb,
            input    clk_wr_i,
            input    rst_wr_ni,
            import   task wait_reset_start(),
            import   task wait_reset_end()
        );


        //SVA para la verificación de señales de escritura
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
        sequence fifo_is_full;
            (wdepth_o == PRIM_ASYNC_FIFO_DEPTH);
        endsequence

        //sequence fifo_is_empty; //No se usa en esta interfaz
        //    (wdepth_o == 0);
        //endsequence

        sequence write_is_blocked;
            (wvalid_i && !wready_o);
        endsequence
        
        //Implementacion de propiedades que puedan validarse como SVA
        
        // INTEGRIDAD DE DATOS
        // PROP-01. N/A (Pertenece al Scoreboard)
        // PROP-02. N/A (Pertenece al Scoreboard)
        // PROP-03. N/A (Pertenece al Scoreboard)
        
        //PROTOCOLO DE INTERFAZ
        // PROP-04. Una vez que `wvalid_i` está activo, permanece activo
        // hasta que se confirma la transferencia.
        property wvalid_i_stable_until_write_is_successful;
            @(posedge clk_wr_i) disable iff(!rst_wr_ni || !has_checks)
            write_is_blocked |=> wvalid_i ==1;
        endproperty
        PROP04_WVALID_STABLE_A : assert property(wvalid_i_stable_until_write_is_successful) else begin
            assert_fail_count++;
            $error("PROP-04: wvalid_i dropped before the transfer completed");
        end

        // PROP-05. Una vez que `wvalid_i` está activo, el dato en `wdata_i`
        // permanece activo hasta que se confirma la transferencia.
        property wdata_i_stable_until_write_is_successful;
            @(posedge clk_wr_i) disable iff(!rst_wr_ni || !has_checks)
            write_is_blocked |=> $stable(wdata_i);//$past(wdata_i) == wdata_i;
        endproperty
        PROP05_WDATA_STABLE_A : assert property(wdata_i_stable_until_write_is_successful) else begin
            assert_fail_count++;
            $error("PROP-05: wdata_i changed while the transfer was blocked");
        end


        // PROP-06. Inactividad durante reset. No se produce ninguna transferencia
        // mientras el reset del dominio está activo.
        // A:
        property no_transfers_while_reset_is_active_a;
            @(posedge clk_wr_i) disable iff(!has_checks)
            //La transferencia se registra por el handshake de wvalid_i == 1 y wready_o == 1
            (rst_wr_ni==0) |-> (wvalid_i==0);
        endproperty
        PROP06A_NO_REQUEST_DURING_RESET_A : assert property(no_transfers_while_reset_is_active_a) else begin
            assert_fail_count++;
            $error("PROP-06a: wvalid_i asserted while the write reset was active");
        end
        // B:
        property no_transfers_while_reset_is_active_b;
            @(posedge clk_wr_i) disable iff(!has_checks)
            //Durante el reset el DUT no debe alterar su estado observable y permanecer en 0
            (rst_wr_ni==0) |-> (wdepth_o==0);
        endproperty
        PROP06B_DEPTH_ZERO_DURING_RESET_A : assert property(no_transfers_while_reset_is_active_b) else begin
            assert_fail_count++;
            $error("PROP-06b: wdepth_o non-zero while the write reset was active");
        end


        //CRUCE DE DOMINIOS
        // PROP-07. N/A (Pertenece al Scoreboard)
        // PROP-08. ‘wdepth_o‘ no excede ‘Depth‘.
        property wdepth_o_is_leq_depth;
            @(posedge clk_wr_i) disable iff(!rst_wr_ni || !has_checks)
            (wdepth_o <= PRIM_ASYNC_FIFO_DEPTH);
        endproperty
        PROP08_WDEPTH_LEQ_DEPTH_A: assert property(wdepth_o_is_leq_depth) else begin
            assert_fail_count++;
            $error("PROP-08: wdepth_o exceeded Depth");
        end

        // PROP-09. N/A (Pertenece al Scoreboard)

        //CONDICIONES LIMITE
        // PROP-10. Bloqueo por lleno. ‘wready_o‘ está inactivo
        // cuando el FIFO está lleno 
        property no_valid_writes_while_wdepth_o_is_full;
            @(posedge clk_wr_i) disable iff(!rst_wr_ni || !has_checks)
            fifo_is_full |-> (wready_o==0);
        endproperty
        PROP10_NO_READY_WHEN_FULL_A : assert property(no_valid_writes_while_wdepth_o_is_full) else begin
            assert_fail_count++;
            $error("PROP-10: wready_o asserted while the FIFO reports full");
        end

        // PROP-11. N/A (Pertenece a la interface de lectura)
        // PROP-12. N/A (Pertenece al Scoreboard)
        // PROP-13. La liberacion del reset debe coincidir con un flanco de clk_wr_i.

        // realtime, NO time: 'time' es integral y redondearia el instante del flanco.
        // Con periodos enteros el redondeo es invisible; con periodos randomizados
        // los flancos caen en fracciones de ns y la comparacion falla, produciendo
        // un falso positivo de PROP-13 en cada liberacion de reset.
        realtime last_wr_clk_edge = 0;
        always @(posedge clk_wr_i) last_wr_clk_edge = $realtime;

        always @(posedge rst_wr_ni) begin
            if (has_checks && $realtime != last_wr_clk_edge) begin
                assert_fail_count++;
                $error("PROP-13: rst_wr_ni was deasserted off a clk_wr_i edge");
            end
        end
        
    endinterface

`endif
