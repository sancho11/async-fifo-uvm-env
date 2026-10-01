#!/usr/bin/env bash
#
# Regresion completa: todos los tests, bajo las tres relaciones de frecuencia,
# con N semillas, y consolidacion de cobertura al final.
#
# ---------------------------------------------------------------------------
# POR QUE ESTE SCRIPT EXISTE Y QUE OPTIMIZA
# ---------------------------------------------------------------------------
# El flujo de XSim tiene tres pasos: xvlog compila, xelab elabora y produce un
# SNAPSHOT, y xsim ejecuta ese snapshot. Compilar y elaborar cuesta unos 20 s;
# ejecutar una corrida cuesta entre 1 y 3 s.
#
# La optimizacion que importa es que el snapshot se construye UNA SOLA VEZ y
# todas las corridas lo reutilizan: lo unico que cambia entre ellas son los
# plusargs y '-sv_seed'. Por eso el objetivo 'run' del Makefile NO depende de
# 'elab'. Una regresion de 90 corridas tarda lo que 90 ejecuciones mas una
# compilacion, no lo que 90 compilaciones.
#
# La segunda optimizacion es WAVES=0: el volcado VCD de una corrida larga ocupa
# varios MB y no se mira en una regresion. Se desactiva por defecto aqui y se
# pide explicitamente cuando hace falta depurar una combinacion concreta.
#
# ---------------------------------------------------------------------------
# COMO SE DECIDE SI UNA CORRIDA PASO
# ---------------------------------------------------------------------------
# No por el codigo de salida de xsim: devuelve 0 SIEMPRE, incluso con UVM_FATAL
# o pidiendo un test inexistente. El banco emite '*** TEST PASSED ***' desde
# final_phase y el objetivo 'check' del Makefile busca ese marcador. Su AUSENCIA
# es fallo, sin importar la causa: un registro truncado, un simulador muerto o un
# test que no llego a arrancar producen todos un registro sin errores.
#
# ---------------------------------------------------------------------------
# USO
#   scripts/run_regression.sh                      # todo, 3 semillas
#   SEEDS="1 2 3 4 5" scripts/run_regression.sh    # mas semillas
#   TESTS="prim_async_fifo_test_03_drain" scripts/run_regression.sh
#   WAVES=1 scripts/run_regression.sh              # con volcado de ondas
#   UVM=accellera scripts/run_regression.sh        # contra la UVM de Accellera
# ---------------------------------------------------------------------------
set -u
cd "$(dirname "$0")/.."

MAKE_FILE=${MAKE_FILE:-Makefile}
RESULTS=${RESULTS:-results}
WAVES=${WAVES:-0}

# Biblioteca UVM: 'vivado' (la precompilada, rapida) o 'accellera' (la fuente
# original). Se deja como opcion porque no son equivalentes: la de Vivado se
# compilo con UVM_HDL_NO_DPI y perdio el calificador 'virtual' en algunos
# metodos de uvm_reg_backdoor, de modo que el acceso backdoor del RAL solo
# funciona con la de Accellera. Este proyecto no usa RAL, pero correr la
# regresion contra las dos es la forma de distinguir un fallo propio de una
# particularidad de la biblioteca.
UVM=${UVM:-vivado}

TESTS=${TESTS:-"prim_async_fifo_test_01_smoke
prim_async_fifo_test_02_fill
prim_async_fifo_test_03_drain
prim_async_fifo_test_04_concurrent
prim_async_fifo_test_05_random
prim_async_fifo_test_06_reset_in_flight"}

# Las tres clases de CP-10. Recorrerlas no es un extra: la relacion de
# frecuencias es constante dentro de una corrida, de modo que los cruces CP-12 a
# CP-15 no pueden pasar de un tercio en ninguna simulacion individual.
CLASSES=${CLASSES:-"wr_faster similar rd_faster"}
SEEDS=${SEEDS:-"1 2 3"}

# TEST-07 va aparte: necesita SIMULATION, que es un define de compilacion, y por
# tanto su propio snapshot. Tampoco se barre por clases: su envolvente de
# validez exige relojes parecidos, y el la fija en su constructor.
CDC_TEST=${CDC_TEST:-prim_async_fifo_test_07_cdc_delay}
CDC_SEEDS=${CDC_SEEDS:-$SEEDS}

# TEST-07 no recibe CLASS: pasarla activaria el plusarg RATIO_CLASS y la clase
# la fija el test en su constructor. El Makefile usa entonces su valor por
# defecto, que es el que acaba en el nombre del registro.
CDC_CLASS_LABEL=${CDC_CLASS_LABEL:-any}

# Contraejemplo. Un test que, con la instrumentacion activa, DEBE fallar: opera
# a caudal maximo y por tanto fuera del envolvente que la cabecera del modulo
# declara. Si pasara, la instrumentacion estaria inerte y el aprobado de TEST-07
# -que si respeta el envolvente- no demostraria nada.
# Es la misma idea que la validacion por inyeccion: comprobar que el montaje
# DISTINGUE, no solo que da verde.
CDC_COUNTER=${CDC_COUNTER:-prim_async_fifo_test_04_concurrent}

# DEFINES y PLUSARGS no se pasan aqui de forma explicita, pero el Makefile los
# declara con '?=' y por tanto los toma del ENTORNO. Para reproducir la campana
# con la instrumentacion CDC de OpenTitan activa:
#
#   DEFINES=SIMULATION PLUSARGS=cdc_instrumentation_enabled=1 scripts/run_regression.sh
#
# No es el modo por defecto para el BARRIDO, y es deliberado: la cabecera del
# modulo fija su condicion de uso -la entrada se salta a lo sumo un ciclo- y la
# relacion de frecuencias que el barrido randomiza la excede. Dentro del
# envolvente si se usa, y de eso se encarga la pasada CDC de mas abajo: TEST-07
# con el estimulo acotado. La documentacion recoge las dos medidas.
mk() { make -f "$MAKE_FILE" --no-print-directory UVM="$UVM" REG_OWNER="$$" "$@"; }

SENTINEL="$RESULTS/.regression_active"

# El centinela avisa a compile/elab de que hay una regresion en marcha. Sin el,
# un 'make all' lanzado en paralelo reescribe el snapshot COMPARTIDO mientras los
# procesos xsim lo estan cargando, y las corridas que arranquen en esa ventana
# ven clases sin sus restricciones. Ocurrio: dos corridas de noventa con
# randomize() devolviendo enteros de 32 bits en crudo.
#
# Se borra en cualquier salida, tambien si se interrumpe con Ctrl-C.
cleanup() { rm -f "$SENTINEL"; }
trap cleanup EXIT INT TERM

# ---- Paso 0: limpieza de artefactos de corridas anteriores -----------------
# Se borran logs, ondas, TCL y CSV, y se conserva el snapshot. Un CSV o un log
# viejo de un test que ya no existe falsearia el consolidado sin avisar.
echo "== Step 0/4: clean per-run artifacts =="
mkdir -p "$RESULTS"
mk clean-results
echo

# ---- Paso 1: un unico snapshot para toda la regresion ---------------------
echo "== Step 1/4: build with UVM=$UVM (one snapshot reused by every run) =="
if ! mk compile elab > "$RESULTS/regression_build.log" 2>&1; then
    echo "BUILD FAILED. See $RESULTS/regression_build.log"
    exit 1
fi
echo "   ok"
echo

# El snapshot ya esta construido: a partir de aqui nadie debe reconstruirlo.
echo $$ > "$SENTINEL"

# ---- Paso 2: barrido ------------------------------------------------------
echo "== Step 2/4: sweep  (tests x frequency classes x seeds) =="
total=0
failed=0
failures=""
# Las aserciones propias del DUT no cuentan para el aprobado -no estan en el
# plan- pero se cuentan aparte: un defecto CDC real las dispara a decenas.
warned=0

for t in $TESTS; do
    for c in $CLASSES; do
        for s in $SEEDS; do
            total=$((total + 1))
            mk run TEST="$t" CLASS="$c" SEED="$s" WAVES="$WAVES" >/dev/null 2>&1
            salida=$(mk check TEST="$t" CLASS="$c" SEED="$s" 2>&1)
            echo "$salida" | grep -q "WARN  DUT-own assertions" && warned=$((warned + 1))
            if echo "$salida" | grep -q "^PASS"; then
                printf "   PASS  %-40s %-10s seed=%s\n" "$t" "$c" "$s"
                echo "$salida" | grep "WARN  DUT-own assertions" || true
            else
                printf "   FAIL  %-40s %-10s seed=%s\n" "$t" "$c" "$s"
                failed=$((failed + 1))
                failures="$failures\n     $t $c seed=$s -> $RESULTS/${t}_${c}_${s}.log"
            fi
        done
    done
done

echo
echo

# ---- Paso 3: consolidacion ----------------------------------------------
# Se ejecuta SIEMPRE, incluso con fallos: una regresion que falla sigue
# produciendo cobertura, y saber que bins quedaron abiertos ayuda a situar el
# fallo.
# ---- Paso 3: segundo snapshot, con la instrumentacion CDC ----------------
# El centinela se MANTIENE durante la reconstruccion. Quitarlo abria una
# ventana en la que el snapshot compartido quedaba desprotegido justo mientras
# se reescribia, que es el escenario que el centinela existe para impedir.
# Quien reconstruye aqui es su dueño, y guard-snapshot lo reconoce por
# REG_OWNER sin necesidad de bajar la guardia.

echo "== Step 3/4: CDC pass  (TEST-07, PROP-09, with OpenTitan instrumentation) =="
if ! mk compile elab DEFINES=SIMULATION > "$RESULTS/regression_build_cdc.log" 2>&1; then
    echo "   BUILD FAILED. See $RESULTS/regression_build_cdc.log"
    failed=$((failed + 1))
else
    for s in $CDC_SEEDS; do
        total=$((total + 1))
        mk run TEST="$CDC_TEST" SEED="$s" WAVES="$WAVES" \
              DEFINES=SIMULATION PLUSARGS=cdc_instrumentation_enabled=1 >/dev/null 2>&1
        if mk check TEST="$CDC_TEST" SEED="$s" >/dev/null 2>&1; then
            printf "   PASS  %-40s %-10s seed=%s\n" "$CDC_TEST" "cdc" "$s"
        else
            printf "   FAIL  %-40s %-10s seed=%s\n" "$CDC_TEST" "cdc" "$s"
            failed=$((failed + 1))
            failures="$failures\n     $CDC_TEST cdc seed=$s -> $RESULTS/${CDC_TEST}_${CDC_CLASS_LABEL}_${s}.log"
        fi
    done

    # ---- Contraejemplo: este DEBE fallar -------------------------------
    total=$((total + 1))
    mk run TEST="$CDC_COUNTER" SEED=1 WAVES="$WAVES" \
          DEFINES=SIMULATION PLUSARGS=cdc_instrumentation_enabled=1 >/dev/null 2>&1
    if mk check TEST="$CDC_COUNTER" SEED=1 >/dev/null 2>&1; then
        printf "   FAIL  %-40s %-10s (should have failed and did not)\n" "$CDC_COUNTER" "counterex."
        echo "         CDC instrumentation looks inert: without it this test passes,"
        echo "         so a pass on $CDC_TEST would prove nothing."
        failed=$((failed + 1))
        failures="$failures\n     $CDC_COUNTER counterexample -> did not fail with instrumentation active"
    else
        printf "   OK    %-40s %-10s (fails, as expected)\n" "$CDC_COUNTER" "counterex."
    fi

fi

# A partir de aqui ya nadie reconstruye: se libera.
rm -f "$SENTINEL"
echo

echo "   $total runs, $failed failed"
if [ "$warned" -gt 0 ]; then
    echo
    echo "   $warned runs fired DUT-OWN assertions."
    echo "   They do not count towards the verdict: they are not part of the plan."
    echo "   A lone firing is usually reset released on the edge; dozens of them"
    echo "   point to a real defect in the clock domain crossing."
fi
if [ "$failed" -ne 0 ]; then
    printf "   Failing combinations:%b\n" "$failures"
fi
echo

echo "== Step 4/4: consolidate coverage =="
python3 scripts/consolidate_coverage.py "$RESULTS"/cov_*.csv

exit $([ "$failed" -eq 0 ] && echo 0 || echo 1)
