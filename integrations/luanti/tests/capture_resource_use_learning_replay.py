"""Freeze checked L12 World records and exact HTTP wires without rewriting inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from .check_resource_use_learning import check


def main():
    parser=argparse.ArgumentParser();parser.add_argument('manifest',type=Path)
    parser.add_argument('--output',type=Path,default=Path('tests/fixtures/luanti_l12_replay.json'))
    args=parser.parse_args();paths=[Path(x) for x in json.loads(args.manifest.read_text(encoding='utf-8-sig'))]
    assert len(paths)==len(set(paths))==12
    runs=[];sources=[]
    for path in paths:
        raw=path.read_bytes();data=json.loads(raw.decode('utf-8-sig'));check(data);runs.append(data)
        sources.append({'file':path.name,'sha256':hashlib.sha256(raw).hexdigest()})
    assert len({(r['world']['scenario'],r['world']['config']['defender']) for r in runs})==12
    assert sum(r['world']['warning_count'] for r in runs)==10
    source_files=[Path(x) for x in ('runtime/resource_use_learning.py','runtime/boundary_defense.py',
                                  'runtime/v23_interpretation.py','runtime/bridge.py')]
    source_files+=list(Path('integrations/luanti/game/rdl_game/mods/rdl_bridge').glob('resource_use*.lua'))
    source_files += [Path(x) for x in ('integrations/luanti/scripts/test-resource-use-learning.ps1',
        'integrations/luanti/scripts/install-game.ps1', 'integrations/luanti/game/rdl_game/mods/rdl_bridge/init.lua',
        'integrations/luanti/game/rdl_game/mods/rdl_bridge/boundary_defense_trial.lua')]
    artifact={'schema':'l12-real-luanti-replay-v1','provenance':{
        'baseline_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'working_tree_implementation':True,'sources':sources,
        'source_sha256':{p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)},
        'method':'Unmodified JSON trees and exact HTTP response wires from 12 independent real Luanti runs. World truth is checker-only.',
        'limitations':'Instrumented peer-use and own-pickup evidence; explicit harness review; finite seven-Episode apparatus; callback fault injection.'},'runs':runs}
    args.output.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'L12 replay saved: {args.output}; 12 runs, 84 Episodes, 10 warnings')


if __name__=='__main__':main()
