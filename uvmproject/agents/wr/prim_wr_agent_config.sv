`ifndef PRIM_WR_AGENT_CONFIG_SV
    `define PRIM_WR_AGENT_CONFIG_SV

    class prim_wr_agent_config extends prim_async_fifo_agent_config_base#(.VIF_T(prim_wr_vif),
                                                                        .DRV_VIF_T(prim_wr_drv_vif),
                                                                        .MON_VIF_T(prim_wr_mon_vif));
        
        `uvm_component_utils(prim_wr_agent_config)
        function new(string name = "", uvm_component parent);
            super.new(name,parent);

        endfunction
    endclass
`endif