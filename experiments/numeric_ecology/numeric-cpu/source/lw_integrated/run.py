"""Single experimental LW-Julia entry; World/clock export only in Python."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--days', type=int, choices=range(1, 5), default=3)
    parser.add_argument('--seed', type=int, default=20261004)
    parser.add_argument('--food', choices=('finite', 'renewable'), default='finite')
    parser.add_argument('--learning', choices=('off', 'full'), default='full')
    parser.add_argument('--hazards', choices=('off', 'crossing'), default='off')
    args = parser.parse_args()
    from integrations.lightweight.world import World
    from runtime.lw_time import metadata
    clock = metadata()
    if clock['profile'] != 'human_scale_v1':
        parser.error('set RDL_LW_TIME_PROFILE=human_scale_v1 before execution')
    world = World('lw-julia-integrated', seed=args.seed, layout='sparse')
    scene = dict(name='lw_sparse', positions=[[a['x'], a['z']] for a in world.agents.values()],
                 food=world.resources, obstacles=[o for o in world.objects if o['solid']],
                 initial_inventory=[0, 2, 2], reserve=[30, 90, 90], home=[0, 4], hearing=True)
    scene['hazards'] = [dict(x=0, z=8, vx=0.05, vz=0, start=60, stop=180)]
    config = dict(hazards=args.hazards, days=args.days, seed=args.seed, food=args.food, learning=args.learning)
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    data = json.dumps(dict(scene=scene, clock=clock, config=config), ensure_ascii=False).encode()
    (out / 'spec.json').write_bytes(data)
    root = Path('experiments/julia_migration')
    sources = sorted(root.rglob('*.jl')) + [Path(__file__), Path('integrations/lightweight/world.py'), Path('runtime/lw_time.py')]
    manifest = dict(name='LW-Julia integrated experiment v1', config=config, clock=clock,
        commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        spec_sha256=hashlib.sha256(data).hexdigest(),
        sources={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        scope='B1g finite scaffold; not production LW parity',
        unported=['full LW hazard/safety parity', 'run/climb/drop', 'spatial resistance and path wear',
                  'general Sleep/T1', 'learned social response policy', 'full landmark relation field'],
        recording='compact transitions + night snapshots; no full observation replay')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    with (out / 'stdout.txt').open('w') as so, (out / 'stderr.txt').open('w') as se:
        subprocess.run(['julia', '--startup-file=no', '--project=experiments/julia_migration/julia',
            str(root / 'lw_integrated/run.jl'), str(out / 'spec.json'), str(out / 'result.json'),
            str(out / 'summary.json')], stdout=so, stderr=se, check=True, timeout=600)
    print((out / 'summary.json').read_text(encoding='utf-8'))


if __name__ == '__main__':
    main()
