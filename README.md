# async-fifo-uvm-env

Entorno de verificación funcional en **UVM 1.2** para `prim_fifo_async`, el FIFO
asíncrono de dos dominios de reloj del proyecto
[OpenTitan](https://github.com/lowRISC/opentitan).

El punto de partida no es el RTL sino el contrato de interfaz: de él se derivan
**trece propiedades** y **diez funcionalidades** que constituyen la
especificación verificable frente a la que se contrasta el diseño.

| | |
|---|---|
| Cobertura | **66 de 66 bins, 100 %** sobre 54 corridas |
| Regresión | 6 tests × 3 relaciones de frecuencia × 3 semillas, **cero fallos** |
| Comprobación | scoreboard con modelo de referencia + **14 aserciones SVA** |
| Defectos en el DUT | ninguno |
| Defectos en el propio entorno | **siete**, documentados con su medición |

📄 **[Documentación del proyecto (PDF)](docs/documentacion-proyecto.pdf)**: Plan de verificación, arquitectura, estrategia de comprobación, resultados y
limitaciones.

---

## Requisitos

- **Vivado XSim** 2026.1 o compatible (`xvlog`, `xelab`, `xsim` en el `PATH`).
- **Python 3** para la consolidación de cobertura.
- Biblioteca UVM. Por defecto se usa la precompilada de Vivado; con
  `UVM=accellera` se compila la de Accellera.

El flujo se desarrolló y se cerró sobre XSim. El apartado de limitaciones de la
documentación recoge las restricciones de la herramienta que condicionaron el
diseño del banco.

## Puesta en marcha

```bash
make check          # comprueba que el entorno esta completo
make all            # compila, elabora y ejecuta el test por defecto
```

Una corrida concreta:

```bash
make run TEST=prim_async_fifo_test_02_fill SEED=7 CLASS=rd_faster WAVES=0
```

| Variable | Valores | Qué hace |
|---|---|---|
| `TEST` | nombre de la clase de test | test a ejecutar |
| `SEED` | entero | semilla de randomización |
| `CLASS` | `any`, `wr_faster`, `similar`, `rd_faster` | relación de frecuencias a ejercitar |
| `WAVES` | `0`, `1` | volcado de ondas |
| `UVM` | `vivado`, `accellera` | biblioteca UVM |
| `DEFINES` | lista de macros | defines de compilación, p. ej. `DEFINES=SIMULATION` |

`DEFINES` llega a `xvlog` como `-d`. Sirve para la geometría del DUT
(`DEFINES=PRIM_ASYNC_FIFO_DEPTH=8`) y para activar la instrumentación CDC de
OpenTitan, descrita más abajo.

## Regresión completa

```bash
SEEDS="1 2 3" scripts/run_regression.sh
```

Recorre todos los tests bajo las tres relaciones de frecuencia, construye **un
único snapshot** y lo reutiliza en todas las ejecuciones, y consolida la
cobertura al terminar. Son 54 corridas.

```bash
make cov-report     # informe de cobertura consolidada
```

El veredicto de cada corrida no se deduce de la ausencia de errores sino de un
**marcador positivo** que el banco emite al terminar: `xsim` devuelve código de
salida cero en todos los casos, incluso al pedirle un test inexistente.

## Estructura

```
uvmproject/
  if/            interfaces, con las 14 aserciones SVA de protocolo
  common/        tipos, item base, bases de configuracion y de cobertura
  agents/wr/     agente del dominio de escritura
  agents/rd/     agente del dominio de lectura
  env/           environment, scoreboard y cobertura funcional
  tests/         test base y catalogo de pruebas
  tb/            testbench top
opentitan/       RTL del DUT (Apache-2.0, no es codigo propio)
scripts/         regresion, consolidacion de cobertura y descarga del DUT
docs/            documentacion del proyecto, en PDF
```

## Instrumentación CDC de OpenTitan

El sincronizador instancia `prim_cdc_rand_delay`, que introduce desorden entre
bits en el cruce de dominios. Está **doblemente desactivado por omisión**: vive
dentro de un `` `ifdef SIMULATION `` y, aun con él definido, solo actúa si se le
pasa un plusarg. Para activarlo:

```bash
make run TEST=prim_async_fifo_test_01_smoke \
     DEFINES=SIMULATION PLUSARGS=cdc_instrumentation_enabled=1
```

**El barrido general no lo activa, y es deliberado.** El módulo documenta su
propia condición de uso en la cabecera —el retardo debe hacer que la entrada se
salte a lo sumo un ciclo—, y la relación de frecuencias que el barrido randomiza
la excede: fuera de ese envolvente el modelo produce valores que nunca estuvieron
en el cable, de modo que un fallo no distinguiría el diseño del instrumento.

**Dentro del envolvente sí se activa.** La regresión tiene una pasada propia, con
su propia elaboración, en la que TEST-07 ejercita PROP-09 con la instrumentación
en marcha y el estímulo acotado para no salirse del margen; CP-11 registra que
estuvo activa, y un contraejemplo que debe fallar acredita que el montaje
distingue. El apartado correspondiente de la documentación recoge las dos
medidas.

## El diseño bajo prueba

`opentitan/` contiene el RTL de OpenTitan, redistribuido bajo su licencia
Apache 2.0 y **sin modificación alguna**. Procede del commit `2c36b23a`, fijado
a propósito: los resultados documentados se obtuvieron contra esa revisión
exacta. La procedencia fichero a fichero está en
[`opentitan/README.md`](opentitan/README.md), y puede comprobarse con:

```bash
scripts/fetch_dut.sh /tmp/ot && diff -r opentitan /tmp/ot
```

## Licencia

El entorno de verificación se publica bajo **Apache-2.0**, la misma licencia del
RTL que verifica. El código de `opentitan/` conserva la suya, con sus cabeceras
y su copia de la licencia en `opentitan/LICENSE`.
