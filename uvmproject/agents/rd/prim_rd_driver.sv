`ifndef PRIM_RD_DRIVER_SV
    `define PRIM_RD_DRIVER_SV

    class prim_rd_driver extends uvm_driver#(.REQ(prim_rd_item_drv)) implements prim_async_fifo_reset_handler;
        prim_rd_agent_config agent_config;
        protected prim_rd_drv_vif vif;

        //Puntero al proceso de drive_transactions() task -> Para manejo de reset
        protected process process_drive_transactions;

        `uvm_component_utils(prim_rd_driver)

        function new(string name = "", uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            recording_detail = agent_config.get_has_recording() ? UVM_FULL : UVM_NONE;

            //Obtener el handler al virtual interface
            //Con el modport de driver
            vif = agent_config.get_drv_vif();
        endfunction

        virtual task wait_reset_end();
            vif.wait_reset_end();
            @(vif.drv_cb);            // <-- alinea el proceso con la cadencia del cb
        endtask

        virtual task run_phase(uvm_phase phase);
            //Lets initialize the driver signals at time 0
            vif.drive_idle(); //Desactivamos todas las señales

            //Then lets handle the signal driving
            forever begin
                fork
                    begin
                        wait_reset_end();
                        drive_transactions();
                    end 
                join
            end
        endtask

        protected virtual task drive_transactions();
            fork
                begin //Task 1
                    process_drive_transactions = process::self();
                    forever begin
                        prim_rd_item_drv item;

                        seq_item_port.get_next_item(item);

                        drive_transaction(item);

                        seq_item_port.item_done();
                    end
                end
            join
        endtask

        protected virtual task drive_transaction(prim_rd_item_drv item);
            bit recording = agent_config.get_has_recording();
            `uvm_info("DEBUG", $sformatf("Driving \" %s\" tem: %s", item.get_full_name(), item.convert2string()), UVM_LOW)

            //Grabacion de transacciones (uvm_transaction): marca el inicio de la
            //transaccion. Se cierra con end_tr() al final de esta tarea.
            if(recording) begin
                void'(begin_tr(item, "rd_drive"));
            end

            //Valid Phase
            while(vif.drv_cb.rvalid_o !== 1) begin
                @(vif.drv_cb);
            end

            //Idle Phase
            for(int i = 0; i < item.pre_drive_delay; i++) begin
                @(vif.drv_cb);
            end

            //Ready Phase
            vif.drv_cb.rready_drv <=1;
            @(vif.drv_cb);
            while (vif.drv_cb.rvalid_o !== 1 || vif.drv_cb.rready_i !== 1) begin
                @(vif.drv_cb);
            end

            //Idle Phase
            vif.drive_idle(); //Desactivamos todas las señales
            for(int i = 0; i < item.post_drive_delay; i++) begin
                @(vif.drv_cb);
            end

            //Cierra la transaccion: su duracion en la base de datos va desde
            //begin_tr() hasta aqui.
            if(recording) begin
                end_tr(item);
            end

        endtask

        virtual function void handle_reset(uvm_phase phase);
            if(process_drive_transactions != null) begin
                process_drive_transactions.kill();
                process_drive_transactions = null;
            end

            vif.drive_idle(); //Desactivamos todas las señales
        endfunction
    
    endclass
`endif