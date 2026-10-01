`ifndef PRIM_WR_SEQUENCE_SIMPLE_SV
    `define PRIM_WR_SEQUENCE_SIMPLE_SV

    // Secuencia simple de escritura: n_items transferencias con dato y
    // retardos randomizados. Los retardos son lo que desbalancea el ritmo
    // entre dominios; sin ellos nunca se alcanzan full ni empty.
    class prim_wr_sequence_simple extends prim_wr_sequence_base;
        `uvm_object_utils(prim_wr_sequence_simple)

        rand int unsigned n_items;
        rand int unsigned max_delay;

        // Cota INFERIOR del espaciado. Por defecto cero, de modo que los tests
        // que solo fijan max_delay se comportan igual que antes de existir.
        // La necesita TEST-07: para que el modelo de instrumentacion CDC de
        // OpenTitan opere dentro de su envolvente, el puntero de origen no debe
        // avanzar mas de un paso Gray por flanco del destino, y eso exige
        // garantizar hueco entre transferencias, no solo permitirlo.
        rand int unsigned min_delay;

        constraint n_items_default   { soft n_items  inside {[1:20]}; }
        constraint max_delay_default { soft max_delay inside {[0:5]};  }
        constraint min_delay_default { soft min_delay == 0; }
        constraint delay_order       { min_delay <= max_delay; }

        function new(string name = "prim_wr_sequence_simple");
            super.new(name);
        endfunction

        virtual task body();
            for (int i = 0; i < n_items; i++) begin
                prim_wr_item_drv item = prim_wr_item_drv::type_id::create($sformatf("item_%0d", i));
                start_item(item);
                if (!item.randomize() with {
                        pre_drive_delay  inside {[min_delay:max_delay]};
                        post_drive_delay inside {[min_delay:max_delay]};
                    }) begin
                    `uvm_fatal("ALGORITHM_ISSUE", "No se pudo randomizar el item de escritura")
                end
                finish_item(item);
            end
        endtask
    endclass
`endif
