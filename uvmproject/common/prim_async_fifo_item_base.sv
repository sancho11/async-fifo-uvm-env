`ifndef PRIM_ASYNC_FIFO_ITEM_BASE_SV
    `define PRIM_ASYNC_FIFO_ITEM_BASE_SV

    class prim_item_base extends uvm_sequence_item;
        rand prim_async_fifo_data data;

        `uvm_object_utils(prim_item_base)

        function new(string name = "");
            super.new(name);
        endfunction

        virtual function string convert2string();
            return $sformatf("data: 0x%h", data);
        endfunction

    endclass
`endif