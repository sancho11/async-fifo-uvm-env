`ifndef PRIM_ASYNC_FIFO_RESET_HANDLER_SV
    `define PRIM_ASYNC_FIFO_RESET_HANDLER_SV

    interface class prim_async_fifo_reset_handler;
        pure virtual function void handle_reset(uvm_phase phase);
    
    endclass

`endif