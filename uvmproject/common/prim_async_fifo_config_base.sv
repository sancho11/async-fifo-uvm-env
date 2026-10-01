`ifndef PRIM_ASYNC_FIFO_CONFIG_BASE_SV
    `define PRIM_ASYNC_FIFO_CONFIG_BASE_SV

    // Banderas de capacidad comunes a CUALQUIER objeto de configuracion del
    // banco, agente o entorno.
    //
    // El criterio del reparto con prim_async_fifo_agent_config_base es si la
    // bandera necesita una interfaz virtual:
    //
    //   - has_coverage y has_recording son banderas puras: solo las lee el
    //     componente que las consulta. Viven aqui.
    //   - has_checks NO lo es: set_has_checks() propaga el valor a vif.has_checks
    //     para habilitar o deshabilitar las aserciones. Se queda en la clase de
    //     agente, que es la unica que tiene vif.
    //
    // Gracias a eso el componente de cobertura del entorno puede configurarse
    // igual que los de los agentes sin heredar nada relacionado con interfaces.
    virtual class prim_async_fifo_config_base extends uvm_component;
        protected bit has_coverage;
        protected bit has_recording;

        function new(string name = "", uvm_component parent);
            super.new(name, parent);

            has_coverage  = 1;
            has_recording = 1;
        endfunction

        virtual function void set_has_coverage(bit value);
            has_coverage = value;
        endfunction

        virtual function bit get_has_coverage();
            return has_coverage;
        endfunction

        virtual function void set_has_recording(bit value);
            has_recording = value;
        endfunction

        virtual function bit get_has_recording();
            return has_recording;
        endfunction

    endclass
`endif
