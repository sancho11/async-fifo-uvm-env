#!/usr/bin/env python3
"""Consolida la cobertura por bin de varias corridas y deriva los cruces.

POR QUE NO SE PROMEDIAN PORCENTAJES
-----------------------------------
Dos corridas al 50 % no dan un 50 % consolidado: si cada una alcanzo un bin
distinto, el conjunto esta al 100 %. El porcentaje es una propiedad del
CONJUNTO de aciertos, no una magnitud promediable. Este script suma aciertos por
bin y recalcula el porcentaje al final.

POR QUE HACEN FALTA LOS CEROS
-----------------------------
Los CSV de entrada listan TODOS los bins, tambien los no alcanzados. Sin esas
filas no habria denominador: seria imposible distinguir un punto de tres bins
con uno vacio de un punto de dos bins completo, ni nombrar lo que falta.

POR QUE LOS CRUCES SE DERIVAN AQUI Y NO SE CUENTAN EN SYSTEMVERILOG
-------------------------------------------------------------------
Un bin de cruce se marca cuando los dos operandos aciertan EN LA MISMA MUESTRA.
Contarlos en el banco obligaria a enumerar a mano 12 y 6 combinaciones,
duplicando el trabajo del covergroup con el riesgo de divergir.

Aqui la derivacion es EXACTA, y no una aproximacion, por una razon concreta: la
relacion de frecuencias es CONSTANTE durante toda una corrida. Por tanto
"el bin B se alcanzo en una corrida de clase C" es equivalente a "B y C
acertaron en la misma muestra". Esa equivalencia es la que hace legitimo
derivar, y deja de valer si algun dia la relacion variase dentro de una
simulacion.
"""
import sys
import csv
from collections import defaultdict

# Cruces del plan de verificacion (3.4.1): id -> operando de estado.
# El segundo operando es siempre CP-10, la relacion de frecuencias.
CROSSES = {
    "CP-11": "CP-04",
    "CP-12": "CP-05",
    "CP-13": "CP-06",
    "CP-14": "CP-07",
}
RATIO_POINT = "CP-10"


def load(paths):
    """hits[cp][bin] = aciertos totales;  by_class[cp][bin] = {clases donde acerto}"""
    hits = defaultdict(lambda: defaultdict(int))
    by_class = defaultdict(lambda: defaultdict(set))
    runs = set()
    classes = set()

    for path in paths:
        with open(path, newline="") as fh:
            for row in csv.DictReader(fh):
                cp, b = row["coverpoint"], row["bin"]
                n = int(row["hits"])
                runs.add((row["test"], row["class"], row["seed"]))
                classes.add(row["class"])
                hits[cp][b] += n
                by_class[cp][b]          # asegura la entrada aunque no haya aciertos
                if n > 0:
                    by_class[cp][b].add(row["class"])
    return hits, by_class, runs, classes


def ratio_classes(hits):
    """Los bins declarados de CP-10: son las columnas de todos los cruces."""
    return sorted(hits.get(RATIO_POINT, {}).keys())


def report_point(cp, bins):
    total = len(bins)
    covered = sum(1 for h in bins.values() if h > 0)
    missing = sorted(b for b, h in bins.items() if h == 0)
    pct = 100.0 * covered / total if total else 0.0
    print("{0:<8} {1:>6.2f}%  {2:<42} {3}".format(
        cp, pct, ", ".join(missing) if missing else "-", sum(bins.values())))
    return total, covered, missing


def report_cross(cross_id, operand, hits, by_class, classes):
    """Un bin de cruce por cada (bin del operando) x (clase de frecuencia)."""
    operand_bins = sorted(hits.get(operand, {}).keys())
    total = len(operand_bins) * len(classes)
    covered = 0
    missing = []

    for b in operand_bins:
        reached_in = by_class[operand].get(b, set())
        for c in classes:
            if c in reached_in:
                covered += 1
            else:
                missing.append("{0}x{1}".format(b, c))

    pct = 100.0 * covered / total if total else 0.0
    shown = ", ".join(missing[:2]) + (" +{0} mas".format(len(missing) - 2) if len(missing) > 2 else "")
    print("{0:<8} {1:>6.2f}%  {2:<42} {3}".format(
        cross_id, pct, shown if missing else "-", "{0}/{1}".format(covered, total)))
    return total, covered, missing


def main(paths):
    if not paths:
        print("No coverage files to consolidate.", file=sys.stderr)
        return 1

    hits, by_class, runs, classes = load(paths)
    classes = sorted(classes)

    print()
    print("Consolidated coverage over {0} runs ({1} frequency classes: {2})".format(
        len(runs), len(classes), ", ".join(classes)))
    print("=" * 78)
    print("{0:<8} {1:>7}  {2:<42} {3}".format("Point", "%", "uncovered bins", "hits"))
    print("-" * 78)

    grand_total = 0
    grand_covered = 0
    holes = []

    for cp in sorted(p for p in hits if p not in CROSSES):
        total, covered, missing = report_point(cp, hits[cp])
        grand_total += total
        grand_covered += covered
        if missing:
            holes.append((cp, missing))

    print("-" * 78)
    print("{0:<8} {1}".format("", "derived crosses (state x frequency ratio)"))
    print("-" * 78)

    for cross_id in sorted(CROSSES):
        operand = CROSSES[cross_id]
        if operand not in hits:
            continue
        total, covered, missing = report_cross(cross_id, operand, hits, by_class, classes)
        grand_total += total
        grand_covered += covered
        if missing:
            holes.append((cross_id, missing))

    print("-" * 78)
    pct = 100.0 * grand_covered / grand_total if grand_total else 0.0
    print("TOTAL    {0:>6.2f}%  {1} of {2} bins covered".format(pct, grand_covered, grand_total))
    print()

    if holes:
        print("Open holes:")
        for cp, missing in holes:
            print("  {0}: {1}".format(cp, ", ".join(missing)))
        print()
        print("A hole is not closed by editing the bin. It is closed with stimulus, or")
        print("justified as structurally unreachable (closure criterion, 3.6).")
    else:
        print("No holes: every declared bin has at least one hit.")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
