`ifndef PRIM_WR_ASYNC_FIFO_AGENT_SV
    `define PRIM_WR_ASYNC_FIFO_AGENT_SV

    class prim_wr_async_fifo_agent extends uvm_agent implements prim_async_fifo_reset_handler;
        //Agent configuration handler
        prim_wr_agent_config agent_config;
        //Sequencer handler
        prim_wr_sequencer sequencer;
        //Driver handler
        prim_wr_driver driver;
        //Monitor handler
        prim_wr_monitor monitor;
        //Coverage handler
        prim_wr_coverage coverage;
        //Virtual Interface handler
        prim_wr_vif vif;

        `uvm_component_utils(prim_wr_async_fifo_agent)

        function new(string name = "", uvm_component parent);
            super.new(name,parent);
        endfunction

        virtual task wait_reset_start();
            vif.wait_reset_start();
        endtask

        virtual task wait_reset_end();
            vif.wait_reset_end();
        endtask

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            agent_config = prim_wr_agent_config::type_id::create("agent_config",this);
            monitor   = prim_wr_monitor::type_id::create("monitor",this);
            
            if (agent_config.get_has_coverage()) begin
                coverage  = prim_wr_coverage::type_id::create("coverage",this);
            end
            if(agent_config.get_active_passive() == UVM_ACTIVE) begin
                sequencer = prim_wr_sequencer::type_id::create("sequencer",this);
                driver    = prim_wr_driver::type_id::create("driver",this);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if(uvm_config_db#(prim_wr_vif)::get(this, "", "wr_vif", vif) == 0) begin
                `uvm_fatal("WR_AGENT_NO_VIF", "Could not get from the database the WR virtual interface")
            end

            //El handle recuperado de la base de datos vive solo dentro de esta funcion.
            //Hay que entregarselo al agent_config, que es quien lo guarda para el resto
            //del agente (driver, monitor, etc.).
            agent_config.set_vif(vif);
            
            //Conectamos los elementos pasivos
            monitor.agent_config = agent_config;

            //Conectamos el coverage
            if (agent_config.get_has_coverage())begin
                coverage.agent_config = agent_config;
                monitor.output_port.connect(coverage.port_item);
            end

            //Conectamos elementos activos
            if (agent_config.get_active_passive() == UVM_ACTIVE) begin
                driver.agent_config=agent_config;
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction

        virtual function void handle_reset(uvm_phase phase);
            //XSim no implementa $cast a interface class. En un simulador que lo soporte,
            //este cuerpo se sustituye por el bucle sobre get_children() + $cast.
            `uvm_info("DEBUG", $sformatf("Executing Reset Handler for each UVM component that requires it."), UVM_NONE)
            if (driver != null) driver.handle_reset(phase);
            if (sequencer != null) sequencer.handle_reset(phase);
            monitor.handle_reset(phase);
            if (coverage != null) coverage.handle_reset(phase);

            ////En un simulador con soporte a $cast a interface class usar esto:
            //uvm_component children[$];
            //get_children(children);
            //foreach(children[idx]) begin
            //    prim_async_fifo_reset_handler reset_handler;
            //    `uvm_info("DEBUG", $sformatf("Handling Reset for Children: %0s", children[idx].get_name()), UVM_NONE)
            //    if($cast(reset_handler,children[idx])) begin
            //        `uvm_info("DEBUG", $sformatf("Handler Found!!!"), UVM_NONE)
            //        reset_handler.handle_reset(phase);
            //    end
            //end
        endfunction

        virtual task run_phase(uvm_phase phase);
            forever begin
                wait_reset_start();
                handle_reset(phase);
                wait_reset_end();
            end
        endtask
    endclass
`endif