"""Experimenter-only SVG map of shared ground history."""
import json
from pathlib import Path


def render(report_path,output):
    report=json.loads(Path(report_path).read_text(encoding='utf8'))
    cells=report['ground_wear']['cells'];points=[tuple(map(int,k.split(','))) for k in cells] or [(0,0)]
    lo_x=min(x for x,z in points)-2;lo_z=min(z for x,z in points)-2
    hi_x=max(x for x,z in points)+3;hi_z=max(z for x,z in points)+3
    scale=min(28,900/(hi_x-lo_x),640/(hi_z-lo_z))
    width=(hi_x-lo_x)*scale+40;height=(hi_z-lo_z)*scale+115
    days=report.get('options',{}).get('days',30)
    roads=sum(c.get('wear',c['distance'])>=10 for c in cells.values())
    restored=sum(c.get('wear',c['distance'])==0 for c in cells.values())
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#e3efd3"/>',
        f'<text x="20" y="26" font-family="sans-serif" font-size="18">Shared ground — {days} days</text>',
        '<text x="20" y="48" font-family="sans-serif" font-size="12">Green: grass / brown: worn ground. Darker = remaining wear; full road at 10 wear units per cell.</text>']
    for key,c in cells.items():
        x,z=map(int,key.split(','));t=min(1,c.get('wear',c['distance'])/10)
        rgb=tuple(round(a+(b-a)*t) for a,b in zip((227,239,211),(111,76,45)))
        wear=c.get('wear',c['distance'])
        outline=' stroke="#779467" stroke-width="0.6" stroke-dasharray="2 2"' if wear==0 else ''
        parts.append(f'<rect x="{20+(x-lo_x)*scale}" y="{65+(hi_z-z-1)*scale}" width="{scale}" height="{scale}" fill="rgb{rgb}"{outline}><title>{key}: wear {wear:.2f}; lifetime distance {c["distance"]:.2f} m; {len(c["agents"])} agents</title></rect>')
    parts.append(f'<text x="20" y="{height-18}" font-family="sans-serif" font-size="12">Road cells: {roads} / Regrown: {restored} (dashed outline). Hover a cell for history. North: up.</text>')
    parts.append('</svg>');svg='\n'.join(parts);Path(output).write_text(svg,encoding='utf8')
    Path(output).with_suffix('.html').write_text('<!doctype html><meta charset="utf-8"><title>Ground paths</title><style>body{margin:24px;background:#f4f6f2;font-family:sans-serif}svg{max-width:100%;height:auto}</style>'+svg,encoding='utf8')


if __name__=='__main__':render('outputs/ground_wear/report.json','outputs/ground_wear/map.svg')
