`ifndef PRIM_RD_ITEM_DRV_SV
    `define PRIM_RD_ITEM_DRV_SV

    class prim_rd_item_drv extends prim_item_base;
        rand int unsigned pre_drive_delay;
        rand int unsigned post_drive_delay;

        constraint pre_drive_delay_default {
            soft pre_drive_delay <=5;
        }

        constraint post_drive_delay_default {
            soft post_drive_delay <=5;
        }

        `uvm_object_utils(prim_rd_item_drv)

        function new(string name = "");
            super.new(name);
            data.rand_mode(0); //Desactivar rand ya que es lectura no escritura
        endfunction

        virtual function string convert2string();
            //string result = super.convert2string();
            string result = $sformatf("pre_drive_delay:  %0d, post_drive_delay: %0d, rdata(rsp): 0x%h", pre_drive_delay, post_drive_delay, data);
            return result;
        endfunction

    endclass
`endif