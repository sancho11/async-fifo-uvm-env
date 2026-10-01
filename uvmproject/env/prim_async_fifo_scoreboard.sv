`ifndef PRIM_ASYNC_FIFO_SCOREBOARD_SV
    `define PRIM_ASYNC_FIFO_SCOREBOARD_SV

    class prim_async_fifo_scoreboard extends uvm_scoreboard implements prim_async_fifo_reset_handler;
        prim_async_fifo_data model[$];          // el modelo de referencia entero

        //Puertos de entrada del scoreboard
        uvm_analysis_imp_wr#(prim_wr_item_mon, prim_async_fifo_scoreboard) wr_imp;
        uvm_analysis_imp_rd#(prim_rd_item_mon, prim_async_fifo_scoreboard) rd_imp;
        uvm_analysis_port#(int unsigned) reset_port;

        //Contadores de transacciones:
        int              wr_items_count;
        int              rd_items_count;
        int reset_discarted_items_count;

        //Scoreboard config
        bit expect_empty_at_end;

        `uvm_component_utils(prim_async_fifo_scoreboard)

        function new(string name = "", uvm_component parent);
            super.new(name, parent);
            //Config
            expect_empty_at_end=0;

            //Input ports
            wr_imp = new("wr_imp", this);
            rd_imp = new("rd_imp", this);

            //Output port
            reset_port = new("reset_port", this);
        endfunction

        function void write_wr(prim_wr_item_mon t);
            model.push_back(t.data);

            // PROP-07. Comportamiento conservador de los reportes de
            // ocupacion. En todo evento se cumple:
            // rdepth_o <= ocupacion_real <= wdepth_o;

            // Cuando un item llega al monitor de escritura comprobamos
            // ocupacion_real <= wdepth_o
            if (model.size() > t.wdepth) begin
                `uvm_error("PROP07", $sformatf("wdepth_o (%0d) is below the real occupancy (%0d): the writer underestimates the fill level", t.wdepth, model.size()))
            end

            wr_items_count++;
        endfunction

        function void write_rd(prim_rd_item_mon t);
            prim_async_fifo_data expected;
            if (model.size() == 0) begin // Lectura sin dato escrito
                `uvm_error("PROP03", $sformatf("read observed with an empty reference model: the DUT delivered data that was never written"))
            end
            expected = model.pop_front();
            if (t.data !== expected) begin
                // PROP-01. Preservacion del orden. Los datos se entregan
                // por el puerto de lectura en el mismo orden que fueron
                // aceptados por el puerto de escritura.
                // PROP-02. Ausencia de perdidas. Todo dato aceptado en
                // escritura es entregado exactamente una vez en lectura,
                // salvo si existe un evento de reset.
                // PROP-03. Ausencia de duplicados. Ningun dato se entrega
                // más de una vez.
                `uvm_error("PROP01", $sformatf("data mismatch: expected 0x%0h, observed 0x%0h", expected, t.data))
            end

            // PROP-07. Comportamiento conservador de los reportes de
            // ocupacion. En todo evento se cumple:
            // rdepth_o <= ocupacion_real <= wdepth_o;

            // Cuando un item llega al monitor de lectura comprobamos
            // rdepth_o <= ocupacion_real
            if (model.size() < t.rdepth) begin
                `uvm_error("PROP07", $sformatf("rdepth_o (%0d) is above the real occupancy (%0d): the reader overestimates the fill level", t.rdepth, model.size()))
            end

            rd_items_count++;
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            `uvm_info("SCOREBOARD", $sformatf("writes=%0d reads=%0d discarded_by_reset=%0d left_in_model=%0d",
              wr_items_count, rd_items_count, reset_discarted_items_count, model.size()), UVM_LOW)
            
            //Errores y warnings
            if (wr_items_count == 0) begin // Sin items de escritura
                `uvm_error("SCOREBOARD", $sformatf("no write transactions were observed: the scoreboard checked nothing"))
            end
            if (rd_items_count + reset_discarted_items_count == 0) begin // Sin items de lectura
                `uvm_error("SCOREBOARD", $sformatf("no read transactions were observed: the scoreboard checked nothing"))
            end
            if (rd_items_count + reset_discarted_items_count > wr_items_count) begin // Sin items de lectura
                `uvm_error("PROP03", $sformatf("more reads (%0d) than writes (%0d) at end of test", rd_items_count, wr_items_count))
            end
            if (rd_items_count + reset_discarted_items_count < wr_items_count) begin // Sin items de lectura
                if (expect_empty_at_end) begin
                    `uvm_error("PROP02", $sformatf("%0d written items were never read (left inside the DUT)", model.size()))
                end else begin
                    `uvm_warning("PROP02", $sformatf("%0d written items were never read (left inside the DUT)", model.size()))
                end
            end
        endfunction


        virtual function void handle_reset(uvm_phase phase);
            //Before deleting the model, publish the model.size() for the coverage module.
            reset_port.write(model.size());

            //Register how much items are we discarting
            reset_discarted_items_count+=model.size();

            //Reset the reference model
            model.delete();
            model = {};

        endfunction
    endclass
`endif