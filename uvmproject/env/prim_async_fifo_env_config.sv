`ifndef PRIM_ASYNC_FIFO_ENV_CONFIG_SV
    `define PRIM_ASYNC_FIFO_ENV_CONFIG_SV

    // Configuracion del entorno. Hoy solo transporta las banderas heredadas,
    // pero existe como objeto propio para que 3.4.10 se cumpla tambien en el
    // env: "los componentes de cobertura se instancian unicamente si el objeto
    // de configuracion lo habilita, de modo que una regresion pueda desactivar
    // la recoleccion sin recompilar".
    class prim_async_fifo_env_config extends prim_async_fifo_config_base;

        `uvm_component_utils(prim_async_fifo_env_config)

        function new(string name = "", uvm_component parent);
            super.new(name, parent);

            // A diferencia de los agentes, aqui el volcado por transaccion
            // imprime los ONCE puntos del entorno en cada item, lo que ahoga el
            // log. El informe util es el de report_phase, que sale una vez al
            // final. Queda desactivado por defecto y se enciende desde el test
            // con set_has_recording(1) cuando hace falta depurar.
            has_recording = 0;
        endfunction

    endclass
`endif
