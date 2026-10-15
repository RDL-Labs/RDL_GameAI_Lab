import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
import sys
from .reference import BASE, SOURCE, prepare, batch, nearest

ROOT = Path('experiments/julia_migration/fixtures')


def export(maintenance=False):
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
    if maintenance:
        for x in (math.nextafter(2.,0.),2.,math.nextafter(2.,3.)):
            add('segment',[0.,0.],[1.,0.],[x,0.,1.],label='maintenance-endpoint-nextafter')
            add('ray',[0.,0.],[1.,0.],[0.,x-1.,1.],label='maintenance-tangent-nextafter')
        actual=json.loads((ROOT/'observed_cast_source.json').read_text())
        body=actual['body'];yaw=math.radians(body['yaw'])
        for obj in actual['objects']:
            add('ray',[body['x'],body['z']],[math.sin(yaw),math.cos(yaw)],
                [obj['x'],obj['z'],obj['radius']],label='observed-world-cast')
    expected = batch([prepare(r) for r in rows])
    groups = []
    for ids in ([6, 6, 9], [0, 3], [], [12, 6, 6]):
        values = [expected[i] for i in ids]
        groups.append(dict(indices=ids, nearest=nearest(values)))
    if maintenance:
        for ids in ([2,2,5],[5,2,2]):
            groups.append(dict(indices=ids,nearest=nearest([expected[i] for i in ids])))
    for name, data in [('geometry_inputs.jsonl', rows), ('geometry_expected.jsonl',
            [dict(id=i, value=v) for i, v in enumerate(expected)]), ('groups.jsonl', groups)]:
        (ROOT/name).write_bytes(''.join(json.dumps(r, allow_nan=False)+'\n' for r in data).encode('utf8'))
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(ROOT.glob('*.jsonl'))}
    meta = dict(baseline=BASE, source_git_blob=subprocess.check_output(['git','rev-parse',f'{BASE}:{SOURCE}'], text=True).strip(),
                seed=20261012, boundaries=46 if maintenance else 40, generated=1000,
                observed_cast=sum(r['label']=='observed-world-cast' for r in rows), hashes=hashes)
    (ROOT/'hashes.json').write_text(json.dumps(meta, indent=2)+'\n', encoding='utf8')
    print(json.dumps(meta))


if __name__ == '__main__': export('--maintenance' in sys.argv)
