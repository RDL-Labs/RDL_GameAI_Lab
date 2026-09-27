"""Preserve every predeclared seed run and verify its producer/source manifest."""
import argparse
import hashlib
import json
from pathlib import Path

from .analyze_multi_resource_seeds import analyze, load
from .run_exploration_series import ROOT, OUTPUT, write


def archive(source, destination, analysis_path):
    panel = load(source)
    for relative, expected in panel['provenance']['source_sha256'].items():
        assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == expected, relative
    for run in panel['runs']:
        path = OUTPUT / run['source']['file']
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == run['source']['sha256'], path
        assert json.loads(raw.decode('utf-8-sig')) == run['data'], path
    result = analyze(panel)
    panel['analysis_source_sha256'] = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
        for name in ('analyze_multi_resource_seeds.py', 'render_multi_resource_seeds.py',
                     'archive_multi_resource_seeds.py', 'check_multi_resource.py')
        for p in [Path(__file__).with_name(name)]}
    write(destination, panel)
    write(analysis_path, result)
    print(destination, destination.stat().st_size, hashlib.sha256(destination.read_bytes()).hexdigest())


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('source', type=Path)
    p.add_argument('destination', type=Path)
    p.add_argument('analysis', type=Path)
    a = p.parse_args()
    archive(a.source, a.destination, a.analysis)
