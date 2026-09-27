"""Experimenter view of L14B measured paths; never a controller input."""
import gzip
import json
from pathlib import Path


def render(matrix, output):
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="990" viewBox="0 0 1240 990">',
        '<rect width="1240" height="990" fill="#f4f3ed"/><g font-family="Arial,sans-serif" fill="#23352e">',
        '<text x="35" y="42" font-size="26" font-weight="bold">L14B / Three explorers sharing finite resources</text>',
        '<text x="35" y="72" font-size="14">Woodland: 8 patches x 12 units. 30 periods. Same terrain and seed; A/C profiles swapped.</text>']
    palette=dict(grass=(119,147,83),dirt=(153,124,86),stone=(111,116,111),
                 trunk=(101,72,43),leaves=(51,91,57),water=(87,150,174))
    colors=['#fff19a','#64def0','#f4a5e5']
    runs=[r for r in matrix['runs'] if r['data']['world']['period_count']==30]
    for panel,r in enumerate(runs):
        w=r['data']['world'];s=r['summary'];x0,y0,step=35+615*panel,148,8
        parts += [f'<text x="{x0}" y="106" font-size="18" font-weight="bold">{s["assignment"].upper()}</text>',
            f'<text x="{x0}" y="132" font-size="14">Collected {s["total_pickups"]}/96; remaining {s["remaining"]}</text>']
        for i,(height,node,top,top_node) in enumerate(w['terrain']['columns']):
            z,x=divmod(i,65);rgb=palette[top_node.removeprefix('rdl_bridge:exploration_')]
            color='#'+''.join(f'{min(255,round(c*(1+height*.045))):02x}' for c in rgb)
            parts.append(f'<rect x="{x0+x*step}" y="{y0+(64-z)*step}" width="8.1" height="8.1" fill="{color}"/>')
        def point(p):return x0+(p['x']+32.5)*step,y0+(32.5-p['z'])*step
        for t in w['resource_trees']:
            x,y=point(t['position']);c='#884d28' if t['color']=='brown' else '#93988f'
            parts.append(f'<rect x="{x-5:.2f}" y="{y-5:.2f}" width="10" height="10" fill="{c}" stroke="#263c28"/>')
        for (agent,a),color in zip(sorted(w['agents'].items()),colors):
            points=[a['initial_body']['position']]+[v['after']['position'] for v in a['actions']]
            coords=' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in points)
            parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="1.7" opacity=".75"/>')
            decisions=r['data']['runtime']['exploration']['agents'][agent]['decisions']
            for o in a['observations']:
                if decisions[o['packet']['observation_id']]['exploration_started']:
                    x,y=point(o['body']['position'])
                    parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="9" fill="none" stroke="{color}" stroke-width="3"/>')
            x,y=point(a['final_body']['position'])
            label_y=y+(18 if agent=='npc_c' else -8)
            parts.append(f'<text x="{x+5:.2f}" y="{label_y:.2f}" font-size="12" font-weight="bold" fill="{color}" stroke="#253d2c" stroke-width="3" paint-order="stroke">{agent[-1].upper()} end</text>')
        for i,p in enumerate(w['final_stock']):
            x,y=point(p['position']);c='#a22c40' if p['remaining'] else '#304d3b'
            parts += [f'<circle cx="{x:.2f}" cy="{y:.2f}" r="5" fill="{c}" stroke="white"/>',
                f'<text x="{x+7:.2f}" y="{y-7:.2f}" font-size="11" font-weight="bold" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">P{i+1}: {p["remaining"]}/12</text>']
        parts.append(f'<text x="{x0}" y="708" font-size="14" font-weight="bold">Agent / profile / units / harvested patches / variation requests</text>')
        for index,(agent,a) in enumerate(sorted(s['agents'].items())):
            y=741+31*index;color=colors[index]
            parts += [f'<rect x="{x0}" y="{y-13}" width="15" height="15" fill="{color}" stroke="#45584e"/>',
                f'<text x="{x0+23}" y="{y}" font-size="14">{agent[-1].upper()} / {a["profile"]} / {a["pickups"]} / {a["patches"]} / {a["exploration_requests"]}</text>']
    parts += ['<text x="35" y="859" font-size="14">Rings mark exploration requests after confirmed M_B predictions. Paths show all measured body moves.</text>',
        '<text x="35" y="889" font-size="14">Patch labels, exact map and remaining stock belong only to this experimenter view.</text>',
        '<text x="35" y="919" font-size="14">Shared depletion changes each history. These two runs alone do not estimate a pure profile effect.</text>',
        '<text x="35" y="949" font-size="14">No hunger, physical collisions, communication, group survival or general boredom model in this fixture.</text>',
        '</g></svg>']
    Path(output).write_text('\n'.join(parts),encoding='utf-8')


if __name__=='__main__':
    import sys
    render(json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes())),sys.argv[2])
