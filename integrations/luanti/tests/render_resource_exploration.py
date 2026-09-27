"""Measured continuous paths and finite stock; never an agent input."""
import gzip
import json
from pathlib import Path


def render(matrix,output):
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="960" viewBox="0 0 1200 960">',
        '<rect width="1200" height="960" fill="#f4f3ed"/>',
        '<g font-family="Arial,sans-serif" fill="#23352e">',
        '<text x="40" y="43" font-size="26" font-weight="bold">L14A / Continuous exploration with finite resource patches</text>',
        '<text x="40" y="73" font-size="14">30 periods per World. Body, stock and inventory persist. Tree-feature learning is not connected.</text>']
    palette=dict(grass=(119,147,83),dirt=(153,124,86),stone=(111,116,111),
                 trunk=(101,72,43),leaves=(51,91,57),water=(87,150,174))
    colors=['#fff19a','#62e0ef','#ed89f1']
    for panel,r in enumerate(r for r in matrix['runs'] if not r['summary']['control']):
        w=r['data']['world'];s=r['summary'];x0,y0,step=40+600*panel,163,8
        label='MEADOW' if s['scenario']=='natural_meadow' else 'WOODLAND'
        parts += [f'<text x="{x0}" y="115" font-size="19" font-weight="bold">{label}</text>',
            f'<text x="{x0}" y="141" font-size="14">{s["pickups"]}/16 units collected; {s["depleted_patches"]}/8 patches depleted; {s["distance"]} nodes walked</text>']
        for i,(height,node,top,top_node) in enumerate(w['terrain']['columns']):
            z,x=divmod(i,65);rgb=palette[top_node.removeprefix('rdl_bridge:exploration_')]
            color='#'+''.join(f'{min(255,round(c*(1+height*.045))):02x}' for c in rgb)
            parts.append(f'<rect x="{x0+x*step}" y="{y0+(64-z)*step}" width="8.1" height="8.1" fill="{color}"/>')
        def point(p):return x0+(p['x']+32.5)*step,y0+(32.5-p['z'])*step
        # Base terrain is the readback before patch-tree insertion; overlay those trees.
        for t in w['resource_trees']:
            x,y=point(t['position']);c='#884d28' if t['color']=='brown' else '#93988f'
            parts.append(f'<rect x="{x-5:.2f}" y="{y-5:.2f}" width="10" height="10" fill="{c}" stroke="#263c28"/>')
        for b,color in enumerate(colors):
            actions=w['actions'][b*640:(b+1)*640]
            path=[actions[0]['before']['position']]+[a['after']['position'] for a in actions]
            coords=' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in path)
            parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="1.8" opacity=".8"/>')
        for i,p in enumerate(w['final_stock']):
            x,y=point(p['position']);c='#a22c40' if p['remaining'] else '#304d3b'
            parts += [f'<circle cx="{x:.2f}" cy="{y:.2f}" r="6" fill="{c}" stroke="white" stroke-width="1.5"/>',
                f'<text x="{x+8:.2f}" y="{y-7:.2f}" font-size="12" font-weight="bold" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">P{i+1}: {p["remaining"]}/2</text>']
        for key,label in [('initial_body','Start'),('final_body','End')]:
            x,y=point(w[key]['position'])
            parts += [f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4" fill="#172f31" stroke="white"/>',
                f'<text x="{x+7:.2f}" y="{y+15:.2f}" font-size="12" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">{label}</text>']
        parts.append(f'<text x="{x0}" y="714" font-size="14" font-weight="bold">Period block / collected units / walking distance</text>')
        for b,stats in enumerate(s['bins']):
            lo,hi=stats['periods'];y=742+26*b
            parts += [f'<rect x="{x0}" y="{y-12}" width="15" height="15" fill="{colors[b]}" stroke="#45584e"/>',
                f'<text x="{x0+24}" y="{y}" font-size="14">{lo}-{hi}: {stats["pickups"]} units / {stats["distance"]} nodes</text>']
    parts += ['<text x="40" y="847" font-size="14">P labels: experimenter patch labels and final stock. Squares: added brown/gray tree surfaces.</text>',
        '<text x="40" y="877" font-size="14">Map, exact positions and stock never enter the agent packet. No teleport or daily resource restoration.</text>',
        '<text x="40" y="909" font-size="14">This is the persistent-resource baseline. Changes across periods do not establish a learning effect.</text>',
        '</g></svg>']
    Path(output).write_text('\n'.join(parts),encoding='utf-8')


if __name__=='__main__':
    import sys
    render(json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes())),sys.argv[2])
