"""Load only two original functions from the frozen Git blob, not a rewrite."""
import ast
import math
import subprocess

BASE = '52a94225484f7e1771c4b4c3703c3eb9eef39730'
SOURCE = 'integrations/lightweight/world.py'
source = subprocess.check_output(['git', 'show', f'{BASE}:{SOURCE}'], text=True)
tree = ast.parse(source)
tree.body = [n for n in tree.body if isinstance(n, ast.FunctionDef)
             and n.name in ('ray_hit', 'segment_hit')]
scope = dict(hypot=math.hypot, sqrt=math.sqrt)
exec(compile(tree, f'{BASE}:{SOURCE}', 'exec'), scope)
ray_hit, segment_hit = scope['ray_hit'], scope['segment_hit']


def prepare(row):
    kind = row['kind']
    if kind not in ('ray', 'segment'):
        raise ValueError('kind')
    start, vector, circle = row['start'], row['vector'], row['circle']
    if len(start) != 2 or len(vector) != 2 or len(circle) != 3:
        raise ValueError('shape')
    values = [*start, *vector, *circle, row['margin']]
    if any(isinstance(x, bool) or not isinstance(x, (int, float)) or
           not math.isfinite(x) or abs(x) > 10000 for x in values):
        raise ValueError('domain')
    if circle[2] < 0 or row['margin'] < 0:
        raise ValueError('negative')
    if kind == 'ray' and abs(math.hypot(*vector)-1) > 1e-12:
        raise ValueError('direction')
    return kind, tuple(start), tuple(vector), dict(x=circle[0], z=circle[1], radius=circle[2]), row['margin']


def batch(queries):
    return [ray_hit(s, v, o) if k == 'ray' else segment_hit(s, v, o, m)
            for k, s, v, o, m in queries]


def nearest(values):
    hits = [(v, i) for i, v in enumerate(values) if v is not None]
    return min(hits, key=lambda x: x[0])[1] if hits else None
