module testbench();

    import uvm_pkg::*;
    import prim_async_fifo_common_pkg::*;
    import prim_async_fifo_pkg::*;
    import prim_async_fifo_test_pkg::*;
    `include "uvm_macros.svh"


    // Clocks
    //
    // SIN valor por defecto a proposito. El unico que decide los periodos es el
    // build_phase del test, que los publica en la config_db; este modulo solo
    // los consume para oscilar. Un valor por defecto aqui seria un segundo
    // origen de verdad: si el get fallara, los relojes irian a una frecuencia y
    // la cobertura clasificaria la relacion sobre otra, sin que nada avisara.
    // Por eso el get de mas abajo es obligatorio y su fallo es fatal.
    real wr_period_ns;
    real rd_period_ns;
    reg  clk_w = 0, clk_r = 0;
    // Startup
    //
    // Todo en un unico initial y en este orden a proposito. Los generadores de
    // reloj NO pueden vivir en su propio bloque: el orden de arranque entre
    // bloques initial no esta garantizado, asi que podrian empezar a oscilar
    // con el valor por defecto antes de que se lean los plusargs.
    initial begin
        // 1. Puente al mundo de las clases: se publica ANTES de run_test(),
        //    porque el build_phase que hara el get() ocurre dentro de el.
        uvm_config_db #(prim_wr_vif)::set(null, "uvm_test_top.env.wr_agent", "wr_vif", wr_vif);
        uvm_config_db #(prim_rd_vif)::set(null, "uvm_test_top.env.rd_agent", "rd_vif", rd_vif);

        // 2. Arranque DIFERIDO de los relojes.
        //
        //    Los periodos los decide el build_phase del test, que no existe
        //    hasta run_test(). Por eso este bloque espera un evento en lugar de
        //    leer los periodos aqui.
        //
        //    El fork/join_none NO es opcional: esperar el evento en linea
        //    bloquea el initial antes de llegar a run_test(), el test nunca se
        //    construye y nadie dispara el evento. El sintoma de ese bloqueo
        //    mutuo es una simulacion que termina en t=0 sin resumen de UVM y
        //    con codigo de salida 0.
        //
        //    Todas las fases de construccion de UVM ocurren en tiempo cero, de
        //    modo que diferir el arranque hasta build_phase no cuesta un solo
        //    picosegundo de simulacion.
        fork
            begin
                uvm_event_pool::get_global("clocks_go").wait_trigger();

                if (!uvm_config_db #(real)::get(null, "", "wr_period_ns", wr_period_ns) ||
                    !uvm_config_db #(real)::get(null, "", "rd_period_ns", rd_period_ns)) begin
                    `uvm_fatal("TB_NO_PERIOD",
                               "Clock periods were not published before triggering 'clocks_go'")
                end

                $display("[TB] periodos: wr=%0.3f ns, rd=%0.3f ns (ratio %0.3f)",
                         wr_period_ns, rd_period_ns, rd_period_ns/wr_period_ns);

                fork
                    forever #(wr_period_ns/2) clk_w = ~clk_w;
                    forever #(rd_period_ns/2) clk_r = ~clk_r;
                join_none
            end
        join_none

        // 3. Drivear las señales de control del dut a su estado por defecto
        //    idle, y reset de encendido. Ambos esperan flancos, asi que quedan
        //    en espera hasta que el paso 2 arranca los relojes. Es correcto y
        //    deliberado: no moverlos por delante del arranque diferido.
        fork wr_vif.drive_idle(); rd_vif.drive_idle(); join_none
        fork wr_vif.do_reset(5); rd_vif.do_reset(5); join_none

        // 4. Cede el control a UVM. No retorna: llama a $finish al acabar.
        run_test();
    end

    //WR Interface
    prim_async_fifo_wr_if #(
        .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
        .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
        .PRIM_ASYNC_FIFO_DATA_WIDTH (PRIM_ASYNC_FIFO_DATA_W)
    ) wr_vif (.clk_wr_i(clk_w));

    //RD Interface
    prim_async_fifo_rd_if #(
        .PRIM_ASYNC_FIFO_DEPTH(PRIM_ASYNC_FIFO_DEPTH_P),
        .PRIM_ASYNC_FIFO_DEPTH_WIDTH(PRIM_ASYNC_FIFO_DEPTH_W),
        .PRIM_ASYNC_FIFO_DATA_WIDTH (PRIM_ASYNC_FIFO_DATA_W)
    ) rd_vif (.clk_rd_i(clk_r));
    
    //DUT
    prim_fifo_async #(
        .Depth(PRIM_ASYNC_FIFO_DEPTH_P),
        .Width(PRIM_ASYNC_FIFO_DATA_W)
    ) dut (
        .clk_wr_i (clk_w),
        .clk_rd_i (clk_r),
        .rst_wr_ni(wr_vif.rst_wr_ni),
        .rst_rd_ni(rd_vif.rst_rd_ni),
        .wvalid_i (wr_vif.wvalid_i),
        .wready_o (wr_vif.wready_o),
        .wdata_i  (wr_vif.wdata_i),
        .wdepth_o (wr_vif.wdepth_o),
        .rvalid_o (rd_vif.rvalid_o),
        .rready_i (rd_vif.rready_i),
        .rdata_o  (rd_vif.rdata_o),
        .rdepth_o (rd_vif.rdepth_o)
    );

endmodule