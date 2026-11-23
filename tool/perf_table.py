"""Compares perf harness runs: python3 tool/perf_table.py before.txt[,before2.txt] after.txt[,after2.txt]

With several runs of one side, each cell is the median (the worst of a run is kept per run, then the median of those).
"""
import json
import statistics
import sys


def load(arg):
    rows = {}
    for path in arg.split(','):
        for line in open(path):
            r = json.loads(line[line.index('{'):])
            rows.setdefault(r['name'], []).append(r)
    return rows


def med(rows, k):
    v = [r[k] for r in rows if k in r]
    return statistics.median(v) if v else None


def fmt(v):
    return '' if v is None else f'{v:g}'


sides = [load(a) for a in sys.argv[1:]]
names = list(dict.fromkeys(n for s in sides for n in s))
print('| Action | ' + ' | '.join(['Build p50 / p90 / worst', 'Raster p50 / p90 / worst', 'Build / raster frames over 16 ms', 'Time or memory']) + ' |')
print('|---|---|---|---|---|')
for n in names:
    cells = [[], [], [], []]
    for s in sides:
        rows = s.get(n, [])
        if med(rows, 'b50') is not None:
            cells[0].append(' / '.join(fmt(med(rows, k)) for k in ('b50', 'b90', 'bmax')))
            cells[1].append(' / '.join(fmt(med(rows, k)) for k in ('r50', 'r90', 'rmax')))
            cells[2].append(f"{fmt(med(rows, 'b16'))} / {fmt(med(rows, 'r16'))} of {fmt(med(rows, 'frames'))}")
        for k, u in (('ms', 'ms'), ('mb', 'MB')):
            if med(rows, k) is not None:
                cells[3].append(f'{fmt(med(rows, k))} {u}')
    print(f'| {n} | ' + ' | '.join(' -> '.join(c) for c in cells) + ' |')
