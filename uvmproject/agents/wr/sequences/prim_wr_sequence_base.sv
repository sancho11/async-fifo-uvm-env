`ifndef PRIM_WR_SEQUENCE_BASE_SV
    `define PRIM_WR_SEQUENCE_BASE_SV

    class prim_wr_sequence_base extends uvm_sequence#(prim_wr_item_drv);
        `uvm_declare_p_sequencer(prim_wr_sequencer)
        `uvm_object_utils(prim_wr_sequence_base)
        
        function new(string name = "");
            super.new(name);
        endfunction
    endclass
`endif