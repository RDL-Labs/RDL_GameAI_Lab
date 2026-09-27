"""Four fixed-terrain seed panels, drawn only from measured World evidence."""
from pathlib import Path
from .analyze_multi_resource_seeds import LATE_START_US, analyze, load, panel_runs


def render(panel, output):
    analysis = analyze(panel)
    runs = panel_runs(panel)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="1500" viewBox="0 0 1240 1500">',
        '<rect width="1240" height="1500" fill="#f4f3ed"/><g font-family="Arial,sans-serif" fill="#23352e">',
        '<text x="35" y="42" font-size="27" font-weight="bold">L14B / Exploration seed and spatial concentration</text>',
        '<text x="35" y="70" font-size="15">Same woodland, starts, profiles and 96 resources. 3 agents x 30 periods per run.</text>']
    palette = dict(grass=(119,147,83), dirt=(153,124,86), stone=(111,116,111),
                   trunk=(101,72,43), leaves=(51,91,57), water=(87,150,174))
    colors = ['#fff19a', '#64def0', '#f4a5e5']
    for index, (run, summary) in enumerate(zip(runs, analysis['runs'])):
        w = run['data']['world']
        x0, y0, step = 35 + (index % 2)*615, 142 + (index // 2)*637, 7
        note = ' (prior run)' if index == 0 else ''
        parts += [f'<text x="{x0}" y="{y0-35}" font-size="19" font-weight="bold">Seed {summary["seed"]}{note}</text>',
            f'<text x="{x0}" y="{y0-12}" font-size="14">Collected {summary["total_pickups"]}/96</text>']
        for i, (height, node, top, top_node) in enumerate(w['terrain']['columns']):
            z, x = divmod(i, 65)
            rgb = palette[top_node.removeprefix('rdl_bridge:exploration_')]
            color = '#' + ''.join(f'{min(255,round(c*(1+height*.045))):02x}' for c in rgb)
            parts.append(f'<rect x="{x0+x*step}" y="{y0+(64-z)*step}" width="7.1" height="7.1" fill="{color}"/>')
        def point(p):
            return x0+(p['x']+32.5)*step, y0+(32.5-p['z'])*step
        for (agent, a), color in zip(sorted(w['agents'].items()), colors):
            # Repeated positions add no geometric information to a path.
            for late in (False, True):
                actions = [v for v in a['actions'] if (v['command']['capture_us'] >= LATE_START_US) == late]
                if not actions:
                    continue
                pts = [actions[0]['before']['position']]
                for v in actions:
                    if v['after']['position'] != pts[-1]:
                        pts.append(v['after']['position'])
                coords = ' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in pts)
                parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="{2 if late else 1.4}" opacity="{.95 if late else .4}"/>')
            x, y = point(a['final_body']['position'])
            label_y = y+(17 if agent == 'npc_c' else -8)
            parts += [f'<circle cx="{x:.2f}" cy="{y:.2f}" r="5" fill="{color}" stroke="#23352e"/>',
                f'<text x="{x+6:.2f}" y="{label_y:.2f}" font-size="13" font-weight="bold" fill="{color}" stroke="#253d2c" stroke-width="3" paint-order="stroke">{agent[-1].upper()}</text>']
        for i, p in enumerate(w['final_stock']):
            x, y = point(p['position'])
            color = '#a22c40' if p['remaining'] else '#304d3b'
            parts += [f'<circle cx="{x:.2f}" cy="{y:.2f}" r="4" fill="{color}" stroke="white"/>',
                f'<text x="{x+6:.2f}" y="{y-6:.2f}" font-size="11" font-weight="bold" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">P{i+1}: {p["remaining"]}</text>']
        parts.append(f'<text x="{x0}" y="{y0+480}" font-size="13" font-weight="bold">Agent / units / requests / late max cell / late distance</text>')
        for i, (agent, a) in enumerate(summary['agents'].items()):
            y = y0+505+i*25
            parts += [f'<rect x="{x0}" y="{y-12}" width="13" height="13" fill="{colors[i]}" stroke="#45584e"/>',
                f'<text x="{x0+21}" y="{y}" font-size="14">{agent[-1].upper()} / {a["pickups"]} / {a["exploration_requests"]} / {100*a["late"]["max_cell_share"]:.1f}% / {a["late"]["distance"]:.1f}</text>']
    parts += ['<text x="35" y="1383" font-size="14">A: steady (yellow). B: curious (cyan). C: restless (pink). All settings stay fixed across seeds.</text>',
        '<text x="35" y="1410" font-size="14">Faint paths: periods 1-10. Bright paths: periods 11-30. Circles/letters: final positions. +z is up.</text>',
        '<text x="35" y="1437" font-size="14">Late max cell = largest capture-sample share in an 8 x 8 node cell; high share alone does not imply a loop.</text>',
        '<text x="35" y="1464" font-size="14">Map and stock labels are audit-only. No same-seed repeats: seed effects are not isolated from timing jitter.</text>',
        '</g></svg>']
    Path(output).write_text('\n'.join(parts), encoding='utf-8')


if __name__ == '__main__':
    import sys
    render(load(sys.argv[1]), sys.argv[2])
