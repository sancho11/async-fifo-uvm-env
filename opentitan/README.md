# RTL del diseño bajo prueba (OpenTitan)

Este directorio **no contiene código propio**. Son fuentes del proyecto
[OpenTitan](https://github.com/lowRISC/opentitan) de lowRISC, redistribuidas
bajo la licencia Apache 2.0 que las ampara (véase `LICENSE`, y las cabeceras
`SPDX-License-Identifier: Apache-2.0` de cada fichero).

## Procedencia

Todos los ficheros proceden del commit:

```
2c36b23a1e0204b20a1d41da7172a0756204b1c8
```

| Fichero | Ruta en el repositorio OpenTitan |
|---|---|
| `prim_fifo_async.sv` | `hw/ip/prim/rtl/` |
| `prim_cdc_rand_delay.sv` | `hw/ip/prim/rtl/` |
| `prim_flop_2sync.sv` | `hw/ip/prim_generic/rtl/` |
| `prim_flop.sv` | `hw/ip/prim_generic/rtl/` |
| `prim_util_pkg.sv` | `hw/ip/prim/rtl/` |
| `prim_assert.sv` | `hw/ip/prim/rtl/` |
| `prim_flop_macros.sv` | `hw/ip/prim/rtl/` |
| `prim_assert_standard_macros.svh` | `hw/ip/prim/rtl/` |
| `prim_assert_dummy_macros.svh` | `hw/ip/prim/rtl/` |
| `prim_assert_sec_cm.svh` | `hw/ip/prim/rtl/` |
| `prim_assert_yosys_macros.svh` | `hw/ip/prim/rtl/` |

## Nota sobre `prim_cdc_rand_delay.sv`

Se incluye porque `prim_flop_2sync.sv` lo instancia, pero **está inerte en la
compilación por defecto**: su cuerpo entero vive dentro de un
`` `ifdef SIMULATION `` que el flujo no define. Sin él, el módulo se reduce a
`assign dst_data_o = src_data_i`.

Conviene saberlo: su mera presencia en el árbol no significa que el cruce de
dominios tenga latencia variable.

## Modificaciones

**Ninguna.** Los ficheros son copia literal del origen. Verificable con:

```bash
scripts/fetch_dut.sh /tmp/ot && diff -r opentitan /tmp/ot
```

El commit está fijado a propósito: los resultados de verificación documentados
se obtuvieron contra esta revisión exacta, y seguir a `master` haría que el banco
verificase un diseño distinto del que la documentación describe.
