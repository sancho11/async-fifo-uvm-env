`ifndef PRIM_RD_MONITOR_SV
    `define PRIM_RD_MONITOR_SV

    class prim_rd_monitor extends uvm_monitor implements prim_async_fifo_reset_handler;
        prim_rd_agent_config agent_config;
        protected prim_rd_mon_vif vif;

        //Puntero al puerto de salida
        uvm_analysis_port#(prim_rd_item_mon) output_port;

        //Puntero al proceso de drive_transactions() task -> Para manejo de reset
        protected process process_collect_transactions;

        `uvm_component_utils(prim_rd_monitor)

        function new(string name = "", uvm_component parent);
            super.new(name, parent);
            output_port = new("output_port", this);
        endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            recording_detail = agent_config.get_has_recording() ? UVM_FULL : UVM_NONE;

            //Obtener el handler al virtual interface
            //Con el modport de monitor
            vif = agent_config.get_mon_vif();
        endfunction

        virtual task wait_reset_end();
            vif.wait_reset_end();
            @(vif.mon_cb);            // <-- alinea el proceso con la cadencia del cb
        endtask

        virtual task run_phase(uvm_phase phase);
            forever begin
                fork
                    begin
                        wait_reset_end();
                        collect_transactions();
                    end 
                join
            end
        endtask

        protected virtual task collect_transactions();
            fork begin
                process_collect_transactions=process::self();
                forever begin
                    collect_transaction();
                end
            end join
        endtask

        protected virtual task collect_transaction();
            prim_rd_item_mon item = prim_rd_item_mon::type_id::create("item");
            bit recording = agent_config.get_has_recording();

            //Wait until idle time is over
            while(vif.mon_cb.rvalid_o !==1)begin
                @(vif.mon_cb);
                item.prev_item_delay++;
            end
            
            if(recording) begin
                void'(begin_tr(item, "rd_monitor"));
            end
            //Valid Phase
            item.data = vif.mon_cb.rdata_o;

            //Ready Phase
            while(vif.mon_cb.rready_i !== 1) begin
                @(vif.mon_cb);
                item.length++;

                // Lets check transaction is not stuck
                if(agent_config.get_has_checks()) begin
                    if(item.length >= agent_config.get_stuck_threshold()) begin
                        `uvm_error("TRANSACTION_ERROR", $sformatf("The transfer reached the stuck threshold of %0d clock cycles", item.length))
                    end
                end
            end
            
            //Transaction Complete
            @(vif.mon_cb);
            item.length++;
            item.rdepth=vif.mon_cb.rdepth_o;

            output_port.write(item);
            `uvm_info("DEBUG", $sformatf("Monitored item: %0s", item.convert2string()), UVM_NONE)
            
            if(recording) begin
                end_tr(item);
            end
        endtask

        virtual function void handle_reset(uvm_phase phase);
            if(process_collect_transactions != null) begin
                process_collect_transactions.kill();
                process_collect_transactions = null;
            end
        endfunction
    
    endclass
`endif