`ifndef PRIM_WR_COVERAGE_SV
    `define PRIM_WR_COVERAGE_SV

    `uvm_analysis_imp_decl(_wr_item)

    class prim_wr_coverage extends prim_async_fifo_coverage_base implements prim_async_fifo_reset_handler;
        prim_wr_agent_config agent_config;
        prim_wr_mon_vif vif;

        //Port for receiving the collected item
        uvm_analysis_imp_wr_item#(prim_wr_item_mon, prim_wr_coverage) port_item;

        `uvm_component_utils(prim_wr_coverage)

        covergroup wr_cover_item with function sample(prim_wr_item_mon wr_item);
            option.per_instance = 1;
            wr_spacing : coverpoint wr_item.prev_item_delay {
                option.comment = "CP-01: Spacing delay between write transactions";
                bins back_to_back  = {0};
                bins short_gap     = {[1:3]};
                bins long_gap      = {[4:$]};
            }
        endgroup

        covergroup cover_reset with function sample(bit valid);
            option.per_instance = 1;

            transaction_ongoing : coverpoint valid {
                option.comment = "CP-03a: A transaction was ongoing at reset";
                bins during_idle     = {0};
                bins during_transfer = {1};
            }
        endgroup

        function new(string name="", uvm_component parent);
            super.new(name, parent);
            
            port_item = new("port_item", this);

            wr_cover_item = new();
            wr_cover_item.set_inst_name($sformatf("%s_%s", get_full_name(),"wr_cover_item"));

            cover_reset = new();
            cover_reset.set_inst_name($sformatf("%s_%s", get_full_name(),"cover_reset"));

            // Predeclaracion de los bins que se contabilizan en paralelo al
            // covergroup. Los nombres replican los de arriba; que la replica sea
            // fiel lo comprueba check_bin_bookkeeping() en cada corrida.
            declare_bin("CP-01.back_to_back");
            declare_bin("CP-01.short_gap");
            declare_bin("CP-01.long_gap");
            declare_bin("CP-03a.during_idle");
            declare_bin("CP-03a.during_transfer");
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
            dump_bins("wr");
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            check_bin_bookkeeping("CP-01", wr_cover_item.wr_spacing.get_inst_coverage());
            check_bin_bookkeeping("CP-03a", cover_reset.transaction_ongoing.get_inst_coverage());
        endfunction

        virtual function string coverage2string();
            string result = {
                $sformatf("\nCP-01: write transaction spacing: %03.2f%%", wr_cover_item.wr_spacing.get_inst_coverage()),
                $sformatf("\nCP-03a: WR agent reset at transaction_ongoing: %03.2f%%", cover_reset.transaction_ongoing.get_inst_coverage())
            };
            return result;
        endfunction

        //virtual task run_phase(uvm_phase phase);    
        //endtask

        virtual function void write_wr_item(prim_wr_item_mon item);
            wr_cover_item.sample(item);
            record_bin({"CP-01.", spacing_bin(item.prev_item_delay)});

            //if(agent_config.get_has_recording()) begin
            //    `uvm_info("DEBUG", $sformatf("Coverage: %0s", coverage2string()),UVM_NONE)
            //end
        endfunction

        virtual function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COVERAGE", $sformatf("Write Agent: %0s", coverage2string()),UVM_NONE)
            
        endfunction

        virtual function void handle_reset(uvm_phase phase);
            cover_reset.sample(vif.mon_cb.wvalid_i && !vif.mon_cb.wready_o);
            record_bin({"CP-03a.", bus_state_bin(vif.mon_cb.wvalid_i && !vif.mon_cb.wready_o)});
        endfunction 

    endclass
`endif