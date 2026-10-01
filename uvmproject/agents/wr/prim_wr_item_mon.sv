`ifndef PRIM_WR_ITEM_MON_SV
    `define PRIM_WR_ITEM_MON_SV

    class prim_wr_item_mon extends prim_item_base;
        int unsigned length;
        int unsigned prev_item_delay;
        int unsigned wdepth;
        

        `uvm_object_utils(prim_wr_item_mon)

        function new(string name = "");
            super.new(name);
        endfunction

        virtual function string convert2string();
            string result = super.convert2string();

            result = $sformatf(
                "%0s, length: %0d, prev_item_delay: %0d",
                 result, length, prev_item_delay);

            return result;
        endfunction


    endclass
`endif