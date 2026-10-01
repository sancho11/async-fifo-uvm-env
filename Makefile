# ===== Flujo XSim (Vivado) =====
#
# Portado desde el Makefile de DSim. La diferencia estructural: DSim compila y
# elabora en un solo comando; XSim lo parte en tres pasos.
#
#   xvlog  -> compila a la libreria 'work' (dentro de xsim.dir/)
#   xelab  -> elabora y genera un snapshot
#   xsim   -> ejecuta el snapshot
#
# Este era Makefile.xsim, paralelo a un Makefile de DSim que permitia correr el
# mismo testbench en los dos simuladores para distinguir un bug propio de una
# limitacion de XSim. Al no haber perspectiva de licencia de DSim, el flujo de
# XSim pasa a ser el unico y este fichero el Makefile por defecto.
#
#   make all
#   make run TEST=prim_async_fifo_test_03_drain SEED=3 CLASS=rd_faster
#   make regress

SHELL := /bin/bash
THIS  := $(firstword $(MAKEFILE_LIST))

# Sin esto, 'make -j' podria lanzar run antes que elab: las dependencias de
# 'all' no garantizan orden en paralelo.
.NOTPARALLEL:

# ===== Entorno de Vivado =====
# El instalador unificado deja settings64.sh en <root>/Vivado/; las instalaciones
# antiguas lo dejan en <root>/. Se prueban las dos rutas.
XILINX_ROOT ?= /mnt/dev_workspace/WDS/Xilinx/2026.1
SETTINGS    ?= $(firstword $(wildcard $(XILINX_ROOT)/Vivado/settings64.sh \
                                      $(XILINX_ROOT)/settings64.sh))

# Arch trae ncurses 6, pero el binario xsim enlaza contra libncurses.so.5 y
# libtinfo.so.5. Vivado incluye ambas en lib/lnx64.o/Ubuntu/24, pero su wrapper
# no reconoce Arch y no las anade al path. Se enlazan SOLO esas dos en un
# directorio propio: meter Ubuntu/24 entero en LD_LIBRARY_PATH shadowearia la
# libstdc++ del sistema para todo proceso hijo, GTKWave incluido.
VIVADO_LIBDIR ?= $(XILINX_ROOT)/Vivado/lib/lnx64.o/Ubuntu/24
COMPAT_DIR    ?= $(HOME)/.local/lib/vivado-compat

# settings64.sh usa sintaxis bash, no fish: por eso SHELL := /bin/bash arriba.
XSIM_ENV = source $(SETTINGS) >/dev/null && \
           export LD_LIBRARY_PATH=$(COMPAT_DIR):$$LD_LIBRARY_PATH &&

# ===== Que libreria UVM usar =====
#
#   UVM=vivado     (por defecto) La precompilada que trae Vivado. Compila rapido
#                  porque ya esta construida. LIMITACION: no permite backdoor de
#                  RAL. Vivado la compilo con UVM_HDL_NO_DPI (peek/poke por
#                  hdl_path mueren con UVM_FATAL) y ademas, al aplanar la
#                  libreria en un solo fichero, perdio el calificador 'virtual'
#                  en uvm_reg_backdoor::read()/write()/read_func(), asi que
#                  tampoco funciona definirse un backdoor propio: el override no
#                  sobrescribe, solo ensombrece.
#
#   UVM=accellera  La fuente original de Accellera (Apache 2.0). Tarda ~1 min
#                  extra la PRIMERA vez que se compila; despues se reutiliza.
#                  Habilita RAL completo, backdoor propio incluido.
#
# Comprobado con un smoke test de RAL: con Accellera pasan frontdoor, predictor
# con prediccion explicita, peek/poke/read(UVM_BACKDOOR) y uvm_reg_hw_reset_seq.
UVM      ?= vivado
UVM_SRC  ?= /mnt/dev_workspace/WDS/Accellera/uvm-1.2/src
UVM_LIB  ?= uvm_acc

# La libreria compilada vive FUERA del proyecto: asi sobrevive a 'make clean' y se
# comparte entre proyectos distintos. Se referencia con la forma -L <nombre>=<dir>.
UVM_LIB_DIR  ?= /mnt/dev_workspace/WDS/Accellera/xsim-lib
UVM_LIB_PATH  = $(UVM_LIB_DIR)/xsim.dir/$(UVM_LIB)
UVM_STAMP     = $(UVM_LIB_PATH)/.built

ifeq ($(UVM),accellera)
  # -i hace falta tambien al compilar el TB: cfs_apb_pkg.sv y compania hacen
  # `include "uvm_macros.svh", que con -L uvm se resolvia solo.
  UVM_COMP = -L $(UVM_LIB)=$(UVM_LIB_PATH) -i $(UVM_SRC) -d UVM_NO_DPI
  UVM_ELAB = -L $(UVM_LIB)=$(UVM_LIB_PATH)
  UVM_DEP  = $(UVM_STAMP)
else ifeq ($(UVM),vivado)
  UVM_COMP = -L uvm
  UVM_ELAB = -L uvm
  UVM_DEP  =
else
  $(error UVM='$(UVM)' no es valido. Usa UVM=vivado o UVM=accellera)
endif

# ===== Optimizacion de elaboracion =====
# xelab tarda ~19 s con optimizacion y ~9,5 s con --O0. En este diseño --O0 NO
# cuesta nada en simulacion (medido: 3525 ms vs 3605 ms por corrida, y 17,6 s vs
# 17,7 s en regresion de 5 semillas): el DUT es pequeño y la optimizacion es puro
# overhead. Para un DUT mucho mayor o simulaciones largas, usar OPT=full.
OPT ?= fast
ifeq ($(OPT),fast)
  OPT_FLAGS = --O0
else ifeq ($(OPT),full)
  OPT_FLAGS =
else
  $(error OPT='$(OPT)' no es valido. Usa OPT=fast o OPT=full)
endif

# ===== Configuracion =====
TOP      ?= testbench
SNAPSHOT ?= image_asyncfifo
PROJECT  ?= uvmproject
RESULTS  ?= results
SRC_DIR  ?= build_sv
FILELIST ?= filelist.f

TEST     ?= ""
VERB     ?= UVM_MEDIUM
SEED     ?= 1
# Sin el '+' inicial: xsim los recibe como '-testplusarg NOMBRE'.
PLUSARGS ?=

# Defines de compilacion adicionales. DEFINES=SIMULATION activa
# prim_cdc_rand_delay dentro de los sincronizadores de OpenTitan; requiere
# ademas el plusarg cdc_instrumentation_enabled=1 en tiempo de ejecucion.
DEFINES  ?=
XVLOG_D   = $(foreach d,$(DEFINES),-d $(d))

# Clase de relacion de frecuencias de la corrida. Se usa en dos sitios: el
# plusarg que la fuerza y la etiqueta con que se marcan las filas del CSV de
# cobertura, para que el consolidado sepa bajo que relacion se obtuvo cada
# acierto.
# Volcado de ondas. Se desactiva en regresion: un VCD de una corrida larga ocupa
# varios MB y nadie lo mira cuando se lanzan decenas de corridas.
WAVES    ?= 1

CLASS    ?= any

# RATIO_CLASS solo se pasa si CLASS se dio de forma EXPLICITA. Pasandolo
# siempre con el valor por defecto, el plusarg sobrescribia la clase que un
# test fija en su constructor, y ningun test podia acotar su geometria de
# relojes. TEST-07 la necesita: su envolvente de validez depende de ella.
ifeq ($(origin CLASS),file)
  RATIO_ARG =
else
  RATIO_ARG = -testplusarg RATIO_CLASS=$(CLASS)
endif
COV_CSV   = $(RESULTS)/cov_$(TEST)_$(CLASS)_$(SEED)

WAVE     = $(RESULTS)/$(TEST)_$(SEED).vcd
WAVELAST = $(RESULTS)/last.vcd
# El nombre incluye la CLASE. Sin ella, las tres clases de una misma semilla
# escribian el mismo fichero y se pisaban: la regresion señalaba tres fallos
# apuntando todos al registro de la ultima corrida.
LOG      = $(RESULTS)/$(TEST)_$(CLASS)_$(SEED).log
GTKW     = $(RESULTS)/$(TEST).gtkw
GTKWLAST = $(RESULTS)/last.gtkw
# Save file a usar: el del test si existe, si no el generico. Permite 'make wave'
# sin pasar TEST=, que es el caso normal cuando solo quieres refrescar.
GTKWUSE  = $(firstword $(wildcard $(GTKW)) $(wildcard $(GTKWLAST)))
TCL      = $(RESULTS)/$(TEST)_$(SEED).tcl
COVDB    = $(RESULTS)/covdb

# ===== Lista de fuentes =====
# xvlog quiere los include dirs como opciones -i, no como lineas +incdir+ dentro
# del fichero -f. Se extraen a INCDIRS y se genera una lista solo con fuentes.
# (Filtrar es inofensivo aunque xvlog aceptase +incdir+, asi que se hace siempre.)
INCDIRS = $(patsubst +incdir+%,-i %,$(filter +incdir+%,$(shell cat $(FILELIST))))
# El nombre incorpora el del filelist de origen. Con un nombre fijo, cambiar
# FILELIST dejaba el generado obsoleto: make lo veia mas reciente que su fuente
# y no lo rehacia, de modo que se elaboraba el DUT anterior sin avisar.
XSIM_F  = $(RESULTS)/filelist_xsim_$(notdir $(FILELIST))

RTL_V  = $(wildcard opentitan/*.v)
RTL_SV = $(patsubst opentitan/%.v,$(SRC_DIR)/%.sv,$(RTL_V))

# ===== Cobertura =====
# Los covergroups no necesitan flag al compilar; lo que hay que pedir es que xsim
# guarde la base de datos. Flags verificados contra 'xsim -help' de la 2026.1.
# Desactivado por defecto; COV=1 para activarlo.
COV      ?= 0
COV_OPTS  = $(if $(filter 1,$(COV)),-cov_db_dir $(COVDB) -cov_db_name $(TEST)_$(SEED),)

# ===== Entorno grafico para GTKWave =====
# SDDM deja la cookie de X en /tmp/xauth_<aleatorio> y ~/.Xauthority puede quedar
# rancio, apuntando al DISPLAY de una sesion anterior. Si eso pasa, GTKWave falla
# con "Authorization required, but no authorization protocol specified".
# Se toma el fichero mas reciente, que es el de la sesion actual.
XAUTH  ?= $(firstword $(shell ls -t /tmp/xauth_* 2>/dev/null))
# LANG del sistema viene como en-US.UTF-8 (guion), que glibc no reconoce.
GUI_ENV = LANG=en_US.UTF-8 $(if $(XAUTH),XAUTHORITY=$(XAUTH),)

.PHONY: all check-env check force-tcl guard-snapshot clean-results cov-report uvm-lib compile elab run wave wave-last wave-force debug regress cov cov-log clean clean-uvm distclean

all: elab run

check-env:
	@test -n "$(SETTINGS)" || { \
	  echo "settings64.sh not found under $(XILINX_ROOT)."; \
	  echo "If Vivado lives elsewhere:  make -f $(THIS) <target> XILINX_ROOT=/real/path"; \
	  exit 1; }
	@mkdir -p $(COMPAT_DIR)
	@for l in libncurses.so.5 libtinfo.so.5; do \
	  test -e $(COMPAT_DIR)/$$l || ln -sf $(VIVADO_LIBDIR)/$$l $(COMPAT_DIR)/$$l; \
	done

$(RESULTS):
	@mkdir -p $(RESULTS)

# El DUT es SystemVerilog con extension .v -> copiar a .sv
$(SRC_DIR)/%.sv: opentitan/%.v
	@mkdir -p $(SRC_DIR)
	@cp $< $@

# Compila la UVM de Accellera a la libreria $(UVM_LIB). Solo se ejecuta si la
# marca no existe, asi que es un coste unico (o tras un 'clean').
uvm-lib: check-env $(UVM_STAMP)

$(UVM_STAMP):
	@echo ">> Compiling Accellera UVM into $(UVM_LIB_DIR)."
	@echo ">> One time only: survives 'clean' and is shared between projects."
	@mkdir -p $(UVM_LIB_DIR)
	$(XSIM_ENV) cd $(UVM_LIB_DIR) && xvlog -sv -work $(UVM_LIB) -i $(UVM_SRC) \
	  -d UVM_NO_DPI $(UVM_SRC)/uvm_pkg.sv -log xvlog_uvm.log
	@touch $@

# Centinela de DEFINES. Sin el, cambiar los defines no invalidaba nada y se
# reutilizaba un snapshot compilado con otros.
# Sello del snapshot: con que configuracion se construyo. 'elab' lo escribe y
# 'run' lo compara, de modo que una discrepancia se detecta antes de medir.
SNAP_STAMP = $(RESULTS)/.snapshot_config
SNAP_CFG   = FILELIST=$(FILELIST) DEFINES=$(DEFINES) UVM=$(UVM)

.PHONY: check-snapshot
check-snapshot:
	@test -f $(SNAP_STAMP) || { \
	  echo "No snapshot built. Run: make elab"; exit 1; }
	@if [ "$$(cat $(SNAP_STAMP))" != "$(SNAP_CFG)" ]; then \
	  echo "SNAPSHOT DOES NOT MATCH WHAT WAS REQUESTED."; \
	  echo "  built with : $$(cat $(SNAP_STAMP))"; \
	  echo "  requested  : $(SNAP_CFG)"; \
	  echo "  Run 'make elab' with those values before running."; \
	  exit 1; \
	fi

DEFINES_STAMP = $(RESULTS)/.defines
.PHONY: force-defines
force-defines: | $(RESULTS)
	@printf '%s' '$(DEFINES)' > $(DEFINES_STAMP).new
	@cmp -s $(DEFINES_STAMP).new $(DEFINES_STAMP) 2>/dev/null || mv $(DEFINES_STAMP).new $(DEFINES_STAMP)
	@rm -f $(DEFINES_STAMP).new

$(XSIM_F): $(FILELIST) | $(RESULTS)
	@grep -v '^[[:space:]]*+incdir+' $(FILELIST) > $@

# -L uvm hace falta en xvlog Y en xelab: la libreria UVM precompilada viene con
# Vivado, no hay que compilar los fuentes de UVM a mano.
# ===== Proteccion del snapshot =====
#
# xsim.dir/$(SNAPSHOT) es UNO para todo el proyecto, y todas las corridas lo
# LEEN. Reconstruirlo mientras una regresion esta en marcha reescribe el fichero
# bajo los pies de los procesos xsim que lo estan cargando: los que arranquen en
# esa ventana veran clases sin sus restricciones y randomize() devolvera enteros
# en crudo. Ocurrio, y solo lo delato el guardia de post_randomize().
#
# El script de regresion deja un centinela con su PID mientras corre. compile y
# elab lo comprueban y abortan con un mensaje claro en lugar de corromper la
# corrida en curso.
REG_SENTINEL = $(RESULTS)/.regression_active

# REG_OWNER lo exporta el script de regresion con su propio PID. Sin el, desde
# que 'run' depende de 'elab' cada corrida de la regresion chocaba contra el
# centinela que la propia regresion habia puesto.
REG_OWNER ?=

# Las dos comprobaciones van en UNA sola receta a proposito. Separadas en dos
# lineas, el 'exit 0' del reconocimiento del dueno terminaba solo su propia
# sub-shell: make pasaba a la linea siguiente y la regresion se rechazaba a si
# misma al reconstruir para la pasada CDC.
guard-snapshot:
	@if [ -f $(REG_SENTINEL) ]; then \
	  owner=$$(cat $(REG_SENTINEL)); \
	  if [ "$(REG_OWNER)" != "$$owner" ] && kill -0 "$$owner" 2>/dev/null; then \
	    echo "REFUSING TO REBUILD: a regression is running (PID $$owner)."; \
	    echo "  The snapshot is shared. Rebuilding it now would corrupt that regression."; \
	    echo "  Wait for it to finish, or run the regression with a different RESULTS dir."; \
	    exit 1; \
	  fi; \
	fi

# Borra los artefactos POR CORRIDA y deja intacto el snapshot: el sentido de que
# 'run' no dependa de 'elab' es reutilizar la compilacion.
clean-results:
	@rm -f $(RESULTS)/*.log $(RESULTS)/*.vcd $(RESULTS)/*.tcl \
	       $(RESULTS)/cov_*.csv $(RESULTS)/*.backup.* $(RESULTS)/*.jou 2>/dev/null || true
	@echo "Per-run artifacts removed from $(RESULTS) (snapshot kept)."

compile: check-env guard-snapshot force-defines $(DEFINES_STAMP) $(UVM_DEP) $(RTL_SV) $(XSIM_F) | $(RESULTS)
	$(XSIM_ENV) xvlog -sv $(UVM_COMP) $(XVLOG_D) $(INCDIRS) -f $(XSIM_F) \
	  -log $(RESULTS)/xvlog.log

# -debug typical es el equivalente al +acc+b de DSim: da acceso a las señales
# para poder volcarlas. Sin esto el VCD sale vacio.
elab: compile guard-snapshot
	$(XSIM_ENV) xelab $(UVM_ELAB) -top $(TOP) -s $(SNAPSHOT) \
	  -timescale 1ns/1ps -debug typical $(OPT_FLAGS) \
	  -log $(RESULTS)/xelab.log
	@printf '%s' '$(SNAP_CFG)' > $(SNAP_STAMP)

# XSim no tiene equivalente directo del '-waves fichero.vcd' de DSim: el volcado
# se pide desde Tcl. Se genera el script al vuelo para no dejar un fichero
# suelto que haya que mantener sincronizado con el nombre del test/seed.
$(TCL): | $(RESULTS)
	@if [ "$(WAVES)" = "0" ]; then \
	  printf '%s\n' 'run -all' 'quit' > $@; \
	else \
	  printf '%s\n' 'open_vcd $(WAVE)' 'log_vcd /*' 'run -all' 'close_vcd' 'quit' > $@; \
	fi

# 'run' no depende de 'elab' a proposito, igual que en el Makefile de DSim: asi
# se puede relanzar con otra seed sin recompilar todo.
#
# OJO con los plusargs de UVM: en XSim solo llegan los que la libreria lee con
# $value$plusargs. UVM_TESTNAME y UVM_VERBOSITY son los DOS unicos que tienen ese
# rescate (uvm_root.svh:453 y :993). Todo lo demas se lee con
# uvm_cmdline_processor, que via DPI mira el argv del proceso -- y '-testplusarg'
# no llega al argv. Se ignoran en silencio.
#
# Por eso NO se pasa aqui '-testplusarg UVM_NO_RELNOTES': se leia con
# clp.get_arg_matches() (uvm_root.svh:357), no hacia absolutamente nada, y las
# release notes salian igual en cada corrida. Comprobado. No volver a anadirlo:
# si molestan las release notes, la unica via es silenciarlas desde codigo.
#
# El resto de plusargs (UVM_MAX_QUIT_COUNT, UVM_TIMEOUT, los *_TRACE...) siguen
# pasandose por PLUSARGS y funcionan porque cfs_algn_test_base.sv los lee en
# start_of_simulation_phase() y llama a la API equivalente. Ver
# docs/xsim-uvm-guia-practica.md apartado 5.
# 'run' NO reconstruye: la regresion construye una vez y reutiliza. Lo que si
# hace es COMPROBAR que el snapshot existente se construyo con la configuracion
# que se le esta pidiendo. Sin esa comprobacion, 'make run DEFINES=...' usaba en
# silencio un snapshot compilado con otros defines y se median cosas distintas
# de las pedidas.
run: check-env check-snapshot force-tcl $(TCL) | $(RESULTS)
	$(XSIM_ENV) xsim $(SNAPSHOT) -tclbatch $(TCL) -sv_seed $(SEED) \
	  -testplusarg UVM_TESTNAME=$(TEST) \
	  -testplusarg UVM_VERBOSITY=$(VERB) \
	  -testplusarg UVM_NO_RELNOTES \
	  $(RATIO_ARG) \
	  -testplusarg COV_CSV=$(COV_CSV) \
	  -testplusarg COV_TEST=$(TEST) \
	  -testplusarg COV_CLASS=$(CLASS) \
	  -testplusarg COV_SEED=$(SEED) \
	  $(foreach p,$(PLUSARGS),-testplusarg $(p)) \
	  $(COV_OPTS) \
	  -log $(LOG)
	@if [ "$(WAVES)" != "0" ]; then $(MAKE) -f $(THIS) --no-print-directory wave-last; fi

# Copia el VCD recien generado sobre $(WAVELAST), que es el fichero que abre
# GTKWave. Asi la ventana ya abierta se refresca con Ctrl+Shift+R tras cualquier
# corrida, sea cual sea el test o la semilla, sin tener que reabrirla.
#
# Se usa 'cp' y NO 'mv' ni un enlace: cp sobrescribe el contenido conservando el
# inodo, que es lo que el descriptor abierto de GTKWave sigue apuntando. Un 'mv'
# crea un inodo nuevo y la instancia abierta se quedaria mirando el fichero
# viejo, recargando siempre la misma onda.
#
# El VCD con nombre propio se conserva: last.vcd es una copia, no un sustituto.
wave-last:
	@test -f $(WAVE) || { echo "$(WAVE) does not exist: nothing to copy to $(WAVELAST)."; exit 1; }
	@cp $(WAVE) $(WAVELAST)
	@echo "[wave] $(WAVE) -> $(WAVELAST)  (Ctrl+Shift+R in GTKWave to refresh)"

# ===== Veredicto de una corrida =====
#
# El banco emite '*** TEST PASSED ***' desde final_phase, y su AUSENCIA es
# fallo. No se busca la presencia de errores, se busca la del marcador: un
# registro truncado, un simulador que ha muerto o un test que no llego a
# arrancar producen todos un registro SIN errores, y los tres deben fallar.
#
# Este objetivo existe porque 'xsim' devuelve codigo de salida 0 en todos los
# casos -comprobado sobre corrida correcta, UVM_FATAL y test inexistente-, de
# modo que el codigo de salida hay que producirlo aqui.
force-tcl:
	@rm -f $(TCL)

# Las aserciones que el propio DUT lleva dentro -prim_fifo_async tiene
# GrayWptr_A y GrayRptr_A- no pasan por ningun contador del entorno, de modo que
# el veredicto del banco no las ve. NO cuentan para el aprobado: no forman parte
# del plan de verificacion, no derivan del contrato y no estan en la matriz de
# trazabilidad, asi que no pueden entrar en un criterio de cierre que no las
# declara.
#
# Pero se avisan, y se cuentan. Un defecto CDC real las dispara a decenas -un
# DUT con el codificador Gray sustituido por un contador binario da 128 en
# TEST-04-, y un aviso con cifra es imposible de pasar por alto. Un disparo
# suelto suele ser otra cosa: el reset asincrono que limpia el puntero a mitad
# de ciclo y se libera justo en el flanco, donde el 'disable iff' de esa
# asercion ya no protege.
check:
	@test -f $(LOG) || { echo "FAIL  $(TEST) seed=$(SEED)  ($(LOG) does not exist)"; exit 1; }
	@if grep -q 'ASSERT FAILED' $(LOG); then \
	  echo "      WARN  DUT-own assertions: $$(grep -c 'ASSERT FAILED' $(LOG)) ($$(grep -oE '\[ASSERT FAILED\] [A-Za-z_0-9]+' $(LOG) | sort -u | sed 's/.*\] //' | tr '\n' ' '))"; \
	fi
	@if grep -q '\*\*\* TEST PASSED \*\*\*' $(LOG); then \
	  echo "PASS  $(TEST) seed=$(SEED)"; \
	else \
	  echo "FAIL  $(TEST) seed=$(SEED)"; \
	  grep -E '\[VERDICT\]|^Error:' $(LOG) | head -4 | sed 's/^/        /'; \
	  exit 1; \
	fi

# Abre el VCD de la ultima corrida, SIEMPRE a traves de $(WAVELAST). Si existe un
# save file se carga la lista de senales guardada (File -> Write Save File).
#
# Si ya hay una instancia abierta no se lanza otra: abrir una nueva perderia las
# senales colocadas a mano. Se recarga desde el GUI con Ctrl+Shift+R.
# Se usa "pgrep -x" (nombre exacto del proceso) y no "-f", porque con -f el propio
# shell que ejecuta esta receta contiene la cadena "gtkwave" y siempre coincidiria.
wave:
	@test -f $(WAVELAST) || { echo "$(WAVELAST) does not exist. Run 'make -f $(THIS) run' first."; exit 1; }
	@if pgrep -x gtkwave >/dev/null 2>&1; then \
	  echo "GTKWave is already open (PID $$(pgrep -x gtkwave | tr '\n' ' ')): not launching another instance."; \
	  echo "Reload the waveform from the GUI with Ctrl+Shift+R  (File -> Reload Waveform)."; \
	else \
	  echo "$(GUI_ENV) gtkwave $(WAVELAST) $(GTKWUSE) &"; \
	  $(GUI_ENV) gtkwave $(WAVELAST) $(GTKWUSE) & \
	fi

# Igual que 'wave' pero lanza una instancia nueva aunque ya haya una abierta.
wave-force:
	@test -f $(WAVELAST) || { echo "$(WAVELAST) does not exist. Run 'make -f $(THIS) run' first."; exit 1; }
	$(GUI_ENV) gtkwave $(WAVELAST) $(GTKWUSE) &

# OJO: los plusargs de traza de UVM (+UVM_PHASE_TRACE, +UVM_OBJECTION_TRACE,
# +UVM_CONFIG_DB_TRACE, +UVM_MAX_QUIT_COUNT...) NO funcionan en XSim. Se leen con
# uvm_cmdline_processor, que via DPI mira el argv del proceso, y en XSim los
# plusargs solo existen en la tabla de $value$plusargs: '-testplusarg' no llega
# al argv y 'xsim +ARG' es rechazado. Medido: cero mensajes de traza.
#
# Las unicas que sobreviven son UVM_TESTNAME y UVM_VERBOSITY, porque UVM 1.2 les
# da un rescate explicito con $value$plusargs (uvm_root.svh:453 y :993).
#
# Para recuperar las trazas hay que llamar a la API equivalente desde el test
# base, leyendo el plusarg con $value$plusargs/$test$plusargs. Ver
# docs/migracion-xsim.md 6.1, que lista el equivalente en codigo de cada uno.
debug:
	$(MAKE) -f $(THIS) run VERB=UVM_HIGH

# ===== Regresion =====
#
# Barre cada test dirigido bajo LAS TRES relaciones de frecuencia. El barrido por
# clase no es un extra: la relacion de frecuencias es constante dentro de una
# corrida, de modo que los cruces CP-11 a CP-14 no pueden pasar de un tercio en
# ninguna simulacion individual. Su cierre solo existe al recorrer las tres.
#
# No se aborta en el primer fallo: interesa el mapa completo de que combinaciones
# fallan, que es lo que distingue un defecto de una casualidad de semilla. El
# codigo de salida se decide al final.
REG_TESTS   ?= prim_async_fifo_test_01_smoke \
               prim_async_fifo_test_02_fill \
               prim_async_fifo_test_03_drain \
               prim_async_fifo_test_04_concurrent \
               prim_async_fifo_test_05_random \
               prim_async_fifo_test_06_reset_in_flight
REG_CLASSES ?= wr_faster similar rd_faster
REG_SEEDS   ?= 1 2 3

regress: 
	@REG_TESTS="$(REG_TESTS)" TESTS="$(REG_TESTS)" CLASSES="$(REG_CLASSES)" SEEDS="$(REG_SEEDS)" \
	  MAKE_FILE=$(THIS) RESULTS=$(RESULTS) WAVES=0 scripts/run_regression.sh

# Consolida los CSV por bin de todas las corridas presentes en $(RESULTS).
cov-report:
	@python3 scripts/consolidate_coverage.py $(RESULTS)/cov_*.csv

# Informe HTML de cobertura funcional a partir de la base de datos acumulada.
#
# OJO: xcrg requiere licencia PRO del simulador. Con la licencia gratuita (tier
# BASIC) falla con "does not meet the requirement to run xcrg". Comprobado
# tambien con el equivalente por Tcl (export_xsim_coverage): bajo BASIC no
# genera nada y no deja ni log.
#
# La RECOGIDA de cobertura si funciona: los covergroups se muestrean y
# cfs_apb_coverage.sv reporta los porcentajes via get_coverage() en el log de
# cada corrida. Usa 'make -f Makefile.xsim cov-log' para verlos.
#
# Este target se deja porque funcionaria tal cual con una licencia PRO.
cov: check-env
	@test -d $(COVDB) || { echo "$(COVDB) does not exist. Run with COV=1 first."; exit 1; }
	@echo ">> xcrg needs a PRO license; with the free one (BASIC) this will fail."
	@echo ">> License-free alternative:  make -f $(THIS) cov-log"
	$(XSIM_ENV) xcrg -cov_db_dir $(COVDB) -report_format html \
	  -report_dir $(RESULTS)/cov_html -log $(RESULTS)/xcrg.log
	@echo "Report in $(RESULTS)/cov_html/index.html"

# Cobertura de la ultima corrida, leida del log. No necesita licencia PRO.
cov-log:
	@test -f $(LOG) || { echo "$(LOG) does not exist. Run 'make -f $(THIS) run' first."; exit 1; }
	@grep -E "^ *(cover_|[a-z_]+: +[0-9]+\.[0-9]+%)|Coverage:|Child component:" $(LOG) || \
	  echo "No coverage data in $(LOG)."

# Solo artefactos de XSim. NO se hace 'rm *.log' a proposito: en la raiz del
# repo viven compile.log, dsim.log y tr_db.log, que son del flujo de DSim y no
# tienen por que morir al limpiar este. Los patrones de abajo no los tocan.
# Nota: NO borra la libreria UVM compartida, que vive en $(UVM_LIB_DIR).
# Para reconstruirla desde cero: make -f Makefile.xsim clean-uvm
clean:
	rm -rf $(RESULTS) xsim.dir xsim.covdb
	rm -f xsim*.jou xsim*.log xvlog.pb xelab.pb xsim.pb $(SNAPSHOT).wdb
	rm -f webtalk*.jou webtalk*.log

clean-uvm:
	rm -rf $(UVM_LIB_DIR)

distclean: clean
	rm -rf $(SRC_DIR)
