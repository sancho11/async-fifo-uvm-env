`ifndef PRIM_WR_ITEM_DRV_SV
    `define PRIM_WR_ITEM_DRV_SV

    class prim_wr_item_drv extends prim_item_base;
        rand int unsigned pre_drive_delay;
        rand int unsigned post_drive_delay;

        constraint pre_drive_delay_default {
            soft pre_drive_delay <=5;
        }

        constraint post_drive_delay_default {
            soft post_drive_delay <=5;
        }

        `uvm_object_utils(prim_wr_item_drv)

        function new(string name = "");
            super.new(name);
        endfunction

        virtual function string convert2string();
            string result = super.convert2string();

            result = $sformatf("%0s, pre_drive_delay:  %0d", result, pre_drive_delay);
            result = $sformatf("%0s, post_drive_delay: %0d", result, post_drive_delay);
            return result;
        endfunction

    endclass
`endif