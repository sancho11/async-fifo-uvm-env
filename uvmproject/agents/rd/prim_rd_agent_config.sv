`ifndef PRIM_RD_AGENT_CONFIG_SV
    `define PRIM_RD_AGENT_CONFIG_SV

    class prim_rd_agent_config extends prim_async_fifo_agent_config_base#(.VIF_T(prim_rd_vif),
                                                                        .DRV_VIF_T(prim_rd_drv_vif),
                                                                        .MON_VIF_T(prim_rd_mon_vif));
        
        `uvm_component_utils(prim_rd_agent_config)
        function new(string name = "", uvm_component parent);
            super.new(name,parent);

        endfunction
    endclass
`endif