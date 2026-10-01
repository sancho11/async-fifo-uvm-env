`ifndef PRIM_ASYNC_FIFO_AGENT_CONFIG_BASE_SV
    `define PRIM_ASYNC_FIFO_AGENT_CONFIG_BASE_SV
    virtual class prim_async_fifo_agent_config_base #(type VIF_T = int,
                                       type DRV_VIF_T = int,
                                       type MON_VIF_T = int) extends prim_async_fifo_config_base;
        protected VIF_T vif;
        protected uvm_active_passive_enum active_passive;
        // has_coverage y has_recording viven en prim_async_fifo_config_base.
        // has_checks se queda aqui porque su setter propaga a vif.has_checks.
        protected bit has_checks;

        //Limite maximo de ciclos
        protected int unsigned stuck_threshold;


        function new(string name = "", uvm_component parent);
            super.new(name,parent);

            active_passive  = UVM_ACTIVE;
            has_checks      = 1;
            stuck_threshold = 1000;
        endfunction

        virtual function VIF_T get_vif();
            return vif;
        endfunction

        virtual function DRV_VIF_T get_drv_vif();
            return vif;
        endfunction

        virtual function MON_VIF_T get_mon_vif();
            return vif;
        endfunction

        virtual function void set_vif(VIF_T value);
            if(vif == null) begin
                vif = value;
                set_has_checks(get_has_checks());
            end
            else begin
                `uvm_fatal("ALGORITHM_ISSUE", $sformatf("%s: virtual interface asignada mas de una vez", get_full_name()))
            end
        endfunction

        virtual function uvm_active_passive_enum get_active_passive();
            return active_passive;
        endfunction

        virtual function void set_active_passive(uvm_active_passive_enum value);
            active_passive = value;
        endfunction

        virtual function void set_has_checks(bit value);
            has_checks=value;
            if(vif != null) begin
                vif.has_checks = has_checks;
            end
        endfunction

        virtual function bit get_has_checks();
            return has_checks;
        endfunction

        virtual function void set_stuck_threshold(int unsigned value);
            if(value <= 1) begin
                `uvm_error("ALGORITHM ISSUE", $sformatf("Tried to set stuck_threshold to value %0d but the minimun lenght of a transfer is 1", value))
            end
            stuck_threshold = value;
        endfunction

        virtual function int unsigned get_stuck_threshold();
            return stuck_threshold;
        endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);
            if(get_vif == null) begin
                `uvm_fatal("ALGORITHM_ISSUE", $sformatf("%s: The virtual interface is not configured at \"Start of simulation\" phase.", get_full_name()))
            end
            else begin
                `uvm_info("AGENT_CONFIG", $sformatf("%s: The virtual interface is configured at \"Start of simulation\" phase", get_full_name()), UVM_LOW)
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            forever begin
                @(vif.has_checks);
                if(vif.has_checks != get_has_checks()) begin
                    `uvm_error("ALGORITHM_ISSUE",$sformatf("Can not change \'has_checks\' from the agent interface directly: Use %0s.set_has_checks() instead", get_full_name()))
                    // Una de las razones por las que manejamos un agent config como un
                    // uvm_component y no solamente como un uvm_object, es la capacidad
                    // de hacer comprobaciones de este tipo en tiempo de ejecución del test.
                end
            end
        endtask

        virtual task wait_reset_start();
            vif.wait_reset_start();
        endtask

        virtual task wait_reset_end();
            vif.wait_reset_end();
        endtask

    endclass
`endif