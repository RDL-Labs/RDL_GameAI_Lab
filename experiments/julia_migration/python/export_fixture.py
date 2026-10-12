import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
from .reference import BASE, SOURCE, prepare, batch, nearest

ROOT = Path('experiments/julia_migration/fixtures')


def export():
    ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    def add(kind, start, vector, circle, margin=0., label='generated'):
        rows.append(dict(id=len(rows), kind=kind, start=start, vector=vector,
                         circle=circle, margin=margin, label=label))
    for z in (0., 1., math.nextafter(1., 0.), math.nextafter(1., 2.), -1.):
        for x in (-2., 0., 2.):
            add('ray', [0., 0.], [1., 0.], [x, z, 1.], label='tangent-front-inside-behind')
    for end in ([0., 0.], [1., 0.], [-1., 0.]):
        for c in ([0., 0., 0.], [2., 0., 1.], [2., 1., 1.], [-2., 0., 1.]):
            for margin in (0., .2):
                add('segment', [0., 0.], end, c, margin, 'zero-endpoint-margin-negative')
    # These are finite domain extremes, not real World objects.
    add('ray', [-10000., -10000.], [1., 0.], [10000., -10000., 0.], label='domain-extreme')
    rng = random.Random(20261012)
    for i in range(1000):
        s = [rng.uniform(-100, 100) for _ in range(2)]
        c = [rng.uniform(-100, 100), rng.uniform(-100, 100), rng.uniform(0, 10)]
        theta = rng.uniform(-math.pi, math.pi)
        v = [math.cos(theta), math.sin(theta)] if i % 2 == 0 else [rng.uniform(-100, 100) for _ in range(2)]
        add('ray' if i % 2 == 0 else 'segment', s, v, c, 0. if i % 2 == 0 else rng.uniform(0, 2))
    expected = batch([prepare(r) for r in rows])
    groups = []
    for ids in ([6, 6, 9], [0, 3], [], [12, 6, 6]):
        values = [expected[i] for i in ids]
        groups.append(dict(indices=ids, nearest=nearest(values)))
    for name, data in [('geometry_inputs.jsonl', rows), ('geometry_expected.jsonl',
            [dict(id=i, value=v) for i, v in enumerate(expected)]), ('groups.jsonl', groups)]:
        (ROOT/name).write_text(''.join(json.dumps(r, allow_nan=False)+'\n' for r in data), encoding='utf8')
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.glob('*.jsonl'))}
    meta = dict(baseline=BASE, source_git_blob=subprocess.check_output(['git','rev-parse',f'{BASE}:{SOURCE}'], text=True).strip(),
                seed=20261012, boundaries=len(rows)-1000, generated=1000, hashes=hashes)
    (ROOT/'hashes.json').write_text(json.dumps(meta, indent=2)+'\n', encoding='utf8')
    print(json.dumps(meta))


if __name__ == '__main__': export()
