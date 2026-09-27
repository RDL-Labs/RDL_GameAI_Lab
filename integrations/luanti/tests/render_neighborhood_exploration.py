"""Measured paths at the controlled revisit; World coordinates are audit-only."""
from html import escape
import gzip
import json
from pathlib import Path


def render(matrix, output):
    branches = matrix["revisit_branches"]
    width = max(1, len(branches)) * 600
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="760" viewBox="0 0 {width} 760">',
             f'<rect width="{width}" height="760" fill="#f4f3ed"/>',
             '<g font-family="Arial,sans-serif" fill="#23352e">',
             '<text x="35" y="40" font-size="24" font-weight="bold">L13V / Learning from a completed search with no Food</text>',
             '<text x="35" y="70" font-size="14">Same accepted history, same reset, same sampler. Only M_B activation differs.</text>']
    palette = dict(grass="#83975d", dirt="#99805c", stone="#8a8f89", trunk="#785737", leaves="#527657", water="#6ba5b9")
    for panel, branch in enumerate(branches):
        active = branch["active"]["days"][-1]["data"]
        inactive = branch["inactive"]["days"][-1]["data"]
        seq = branch["comparison"]["first_difference_sample"]
        i = next(i for i, o in enumerate(active["world"]["observations"]) if o["packet"]["sample_seq"] == seq)
        anchor = active["world"]["observations"][i]["body"]["position"]
        x0, y0, size, scale = 35 + panel * 600, 150, 520, 28
        parts += [f'<text x="{x0}" y="109" font-size="20" font-weight="bold">{escape(branch["scenario"].removeprefix("natural_").upper())}</text>',
                  f'<text x="{x0}" y="134" font-size="14">First different command at sample {seq}; next 17 acquisition positions</text>',
                  f'<clipPath id="panel{panel}"><rect x="{x0}" y="{y0}" width="{size}" height="{size}"/></clipPath>',
                  f'<g clip-path="url(#panel{panel})">',
                  f'<rect x="{x0}" y="{y0}" width="{size}" height="{size}" fill="#d6d8cb"/>']
        def point(pos):
            return x0+size/2+(pos["x"]-anchor["x"])*scale, y0+size/2-(pos["z"]-anchor["z"])*scale
        for n, (_, _, _, node) in enumerate(active["world"]["terrain"]["columns"]):
            z, x = divmod(n, 65)
            px, py = point(dict(x=x-32.5, z=z-31.5))
            color = palette[node.removeprefix("rdl_bridge:exploration_")]
            parts.append(f'<rect x="{px:.2f}" y="{py:.2f}" width="{scale+.1}" height="{scale+.1}" fill="{color}" opacity=".55"/>')
        for data, color, dash in ((inactive, "#b74357", "5 3"), (active, "#006b7c", "none")):
            obs = data["world"]["observations"][i:i+17]
            coords = ' '.join(f'{point(o["body"]["position"])[0]:.2f},{point(o["body"]["position"])[1]:.2f}' for o in obs)
            parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="3" stroke-dasharray="{dash}"/>')
            for o in obs:
                px, py = point(o["body"]["position"])
                parts.append(f'<circle cx="{px:.2f}" cy="{py:.2f}" r="2.5" fill="{color}"/>')
        px, py = point(anchor)
        parts += [f'<circle cx="{px}" cy="{py}" r="6" fill="#f4f3ed" stroke="#23352e" stroke-width="2"/>',
                  f'<text x="{px+10}" y="{py-12}" font-size="13" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">Matched starting view</text>',
                  '</g>',
                  f'<text x="{x0}" y="698" font-size="14" fill="#006b7c">Activated: wait, then select another observed subgoal</text>',
                  f'<text x="{x0}" y="722" font-size="14" fill="#b74357">Not activated: turn -90 degrees, repeat the two excursions</text>']
    parts += ['<text x="35" y="748" font-size="12">Measured horizontal positions; repeated points include turns/waits. Audit map, not agent input. Explicit reentry, not learned homing.</text>', '</g></svg>']
    Path(output).write_text('\n'.join(parts), encoding='utf-8')


if __name__ == "__main__":
    import sys
    render(json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes())), sys.argv[2])
