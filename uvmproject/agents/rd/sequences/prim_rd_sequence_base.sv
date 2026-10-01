`ifndef PRIM_RD_SEQUENCE_BASE_SV
    `define PRIM_RD_SEQUENCE_BASE_SV

    class prim_rd_sequence_base extends uvm_sequence#(prim_rd_item_drv);
        `uvm_declare_p_sequencer(prim_rd_sequencer)
        `uvm_object_utils(prim_rd_sequence_base)
        
        function new(string name = "");
            super.new(name);
        endfunction
    endclass
`endif