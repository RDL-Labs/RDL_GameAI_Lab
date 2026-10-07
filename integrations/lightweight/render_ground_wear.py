"""Experimenter-only SVG map of shared ground history."""
import json
from pathlib import Path


def render(report_path,output):
    report=json.loads(Path(report_path).read_text(encoding='utf8'))
    cells=report['ground_wear']['cells'];points=[tuple(map(int,k.split(','))) for k in cells]
    lo_x=min(x for x,z in points)-2;lo_z=min(z for x,z in points)-2
    hi_x=max(x for x,z in points)+3;hi_z=max(z for x,z in points)+3
    scale=min(28,900/(hi_x-lo_x),640/(hi_z-lo_z))
    width=(hi_x-lo_x)*scale+40;height=(hi_z-lo_z)*scale+85
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#e3efd3"/>',
        '<text x="20" y="26" font-family="sans-serif" font-size="18">Shared ground — 30 days</text>',
        '<text x="20" y="48" font-family="sans-serif" font-size="12">Green: grass / brown: worn ground. Darker = more walking; full road at 10 wear units per cell.</text>']
    for key,c in cells.items():
        x,z=map(int,key.split(','));t=min(1,c.get('wear',c['distance'])/10)
        rgb=tuple(round(a+(b-a)*t) for a,b in zip((191,209,149),(111,76,45)))
        parts.append(f'<rect x="{20+(x-lo_x)*scale}" y="{65+(hi_z-z-1)*scale}" width="{scale}" height="{scale}" fill="rgb{rgb}"><title>{key}: {c["distance"]:.2f} m; {len(c["agents"])} agents</title></rect>')
    parts.append('</svg>');Path(output).write_text('\n'.join(parts),encoding='utf8')


if __name__=='__main__':render('outputs/ground_wear/report.json','outputs/ground_wear/map.svg')
