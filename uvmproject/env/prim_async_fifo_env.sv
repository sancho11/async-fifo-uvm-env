`ifndef PRIM_ASYNC_FIFO_ENV_SV
    `define PRIM_ASYNC_FIFO_ENV_SV

    class prim_async_fifo_env extends uvm_env;
        //Definimos los agentes que contendra el enviroment:
        prim_wr_async_fifo_agent wr_agent;
        prim_rd_async_fifo_agent rd_agent;
        prim_async_fifo_scoreboard scoreboard;
        prim_async_fifo_env_config env_config;
        prim_async_fifo_coverage coverage;

        //Macro UVM para registrar clase en factory
        `uvm_component_utils(prim_async_fifo_env)

        //Constructor
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            //Durante el build phase instanciamos los agentes
            wr_agent = prim_wr_async_fifo_agent::type_id::create("wr_agent",this);
            rd_agent = prim_rd_async_fifo_agent::type_id::create("rd_agent",this);

            //El scoreboard
            scoreboard = prim_async_fifo_scoreboard::type_id::create("scoreboard",this);

            //La configuracion del entorno
            env_config = prim_async_fifo_env_config::type_id::create("env_config",this);

            //El coverage, solo si la configuracion lo habilita (3.4.10)
            if (env_config.get_has_coverage()) begin
                coverage = prim_async_fifo_coverage::type_id::create("coverage",this);
            end

        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            wr_agent.monitor.output_port.connect(scoreboard.wr_imp);
            rd_agent.monitor.output_port.connect(scoreboard.rd_imp);
            if (env_config.get_has_coverage()) begin
                coverage.env_config = env_config;
                wr_agent.monitor.output_port.connect(coverage.wr_imp);
                rd_agent.monitor.output_port.connect(coverage.rd_imp);
                scoreboard.reset_port.connect(coverage.reset_imp);
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            reset_watcher(phase);
        endtask

        virtual task reset_watcher(uvm_phase phase);
            forever begin
                fork
                    rd_agent.wait_reset_start();
                    wr_agent.wait_reset_start();
                join_any
                disable fork;
                //PROP 12. Los reset son activados de manera simultanea
                if (wr_agent.vif.rst_wr_ni || rd_agent.vif.rst_rd_ni) begin
                    `uvm_error("PROP-12", $sformatf("Asynchronous reset assertion is not occourring simultaneously: rst_wr_ni-> %0d rst_rd_ni-> %0d",wr_agent.vif.rst_wr_ni, rd_agent.vif.rst_rd_ni))
                end
                scoreboard.handle_reset(phase);
                if (coverage != null) coverage.handle_reset(phase);
                fork
                    rd_agent.wait_reset_end();
                    wr_agent.wait_reset_end();
                join
            end
        endtask

    endclass: prim_async_fifo_env
`endif