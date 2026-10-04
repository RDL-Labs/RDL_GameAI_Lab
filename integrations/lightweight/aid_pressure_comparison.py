"""Hold Sleep adoption fixed while enabling same-day request H."""
from collections import Counter
import gzip
import json
from pathlib import Path
from .timed_harvest import run
from .social_life_comparison import OPTIONS,audit


def main():
    root=Path('tests/fixtures/aid_pressure');root.mkdir(parents=True,exist_ok=True)
    out=Path('outputs/aid_pressure');out.mkdir(parents=True,exist_ok=True);report={}
    for enabled in (False,True):
        name='enabled' if enabled else 'disabled';path=out/(name+'.jsonl')
        summary=run(path,**dict(OPTIONS,body_scene='social_camp',social_adopt=True,social_pressure=enabled))
        summary.pop('elapsed_seconds',None);checked=audit(path)
        assert checked['conserved'] and not checked['body_overlap']
        report[name]=dict(summary=summary,audit=checked)
        with gzip.GzipFile(filename=str(root/(name+'.jsonl.gz')),mode='wb',mtime=0) as f:f.write(path.read_bytes())
        print(name,Counter((r['day'],r['target']) for r in checked['requests']),checked['actions'],flush=True)
    (root/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':main()
