`ifndef PRIM_RD_COVERAGE_SV
    `define PRIM_RD_COVERAGE_SV

    `uvm_analysis_imp_decl(_rd_item)

    class prim_rd_coverage extends prim_async_fifo_coverage_base implements prim_async_fifo_reset_handler;
        prim_rd_agent_config agent_config;
        prim_rd_mon_vif vif;

        //Port for receiving the collected item
        uvm_analysis_imp_rd_item#(prim_rd_item_mon, prim_rd_coverage) port_item;

        `uvm_component_utils(prim_rd_coverage)

        covergroup rd_cover_item with function sample(prim_rd_item_mon rd_item);
            option.per_instance = 1;
            rd_spacing : coverpoint rd_item.prev_item_delay {
                option.comment = "CP-02: Spacing delay between read transactions";
                bins back_to_back  = {0};
                bins short_gap     = {[1:3]};
                bins long_gap      = {[4:$]};
            }
        endgroup

        covergroup cover_reset with function sample(bit valid);
            option.per_instance = 1;

            transaction_ongoing : coverpoint valid {
                option.comment = "CP-03b: A transaction was ongoing at reset";
                bins during_idle     = {0};
                bins during_transfer = {1};
            }
        endgroup

        function new(string name="", uvm_component parent);
            super.new(name, parent);
            
            port_item = new("port_item", this);

            rd_cover_item = new();
            rd_cover_item.set_inst_name($sformatf("%s_%s", get_full_name(),"rd_cover_item"));

            cover_reset = new();
            cover_reset.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_reset"));

            // Predeclaracion de los bins que se contabilizan en paralelo al
            // covergroup. Los nombres replican los de arriba; que la replica sea
            // fiel lo comprueba check_bin_bookkeeping() en cada corrida.
            declare_bin("CP-02.back_to_back");
            declare_bin("CP-02.short_gap");
            declare_bin("CP-02.long_gap");
            declare_bin("CP-03b.during_idle");
            declare_bin("CP-03b.during_transfer");
        endfunction

        //virtual function void build_phase(uvm_phase phase);
        //    super.build_phase(phase);
        //endfunction

        virtual function void start_of_simulation_phase(uvm_phase phase);
            super.start_of_simulation_phase(phase);

            //Obtener el handler al virtual interface
            //Con el modport de monitor
            vif = agent_config.get_mon_vif();
        endfunction

        virtual function void extract_phase(uvm_phase phase);
            super.extract_phase(phase);
            dump_bins("rd");
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            check_bin_bookkeeping("CP-02", rd_cover_item.rd_spacing.get_inst_coverage());
            check_bin_bookkeeping("CP-03b", cover_reset.transaction_ongoing.get_inst_coverage());
        endfunction

        virtual function string coverage2string();
            string result = {
                $sformatf("\nCP-02: read transaction spacing: %03.2f%%", rd_cover_item.rd_spacing.get_inst_coverage()),
                $sformatf("\nCP-03b: RD agent reset at transaction_ongoing: %03.2f%%", cover_reset.transaction_ongoing.get_inst_coverage())
            };
            return result;
        endfunction

        //virtual task run_phase(uvm_phase phase);    
        //endtask

        virtual function void write_rd_item(prim_rd_item_mon item);
            rd_cover_item.sample(item);
            record_bin({"CP-02.", spacing_bin(item.prev_item_delay)});

            //if(agent_config.get_has_recording()) begin
            //    `uvm_info("DEBUG", $sformatf("Coverage: %0s", coverage2string()),UVM_NONE)
            //end
        endfunction

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COVERAGE", $sformatf("Read Agent: %0s", coverage2string()),UVM_NONE)
            
        endfunction

        virtual function void handle_reset(uvm_phase phase);
            cover_reset.sample(vif.mon_cb.rvalid_o && !vif.mon_cb.rready_i);
            record_bin({"CP-03b.", bus_state_bin(vif.mon_cb.rvalid_o && !vif.mon_cb.rready_i)});
        endfunction 

    endclass

`endif