"""Experimenter-only terrain map from actual node readbacks and body trajectories.

SVG is a native vector diagram, not a Luanti client screenshot or agent input.
"""
import gzip
import json
from pathlib import Path
import sys


def render(matrix, output):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="810" viewBox="0 0 1200 810">',
             '<rect width="1200" height="810" fill="#f4f3ed"/>',
             '<g font-family="Arial,sans-serif" fill="#23352e">',
             '<text x="40" y="45" font-size="25" font-weight="bold">L13T  /  Exploration on natural terrain</text>',
             '<text x="40" y="72" font-size="14">Actual node readback + measured movement. Experimenter view; the agent never receives this map.</text>']
    palette = dict(grass=(119,147,83), dirt=(153,124,86), stone=(111,116,111),
                   trunk=(101,72,43), leaves=(51,91,57), water=(87,150,174))
    for panel, s in enumerate(matrix["series"]):
        x0, y0, step = 40+600*panel, 154, 8
        w = s["days"][0]["data"]["world"]
        summary = s["state"]["summary"]
        days = [d["day"] if d else "-" for d in summary["discoveries"]]
        label = "MEADOW" if panel == 0 else "WOODLAND"
        parts.append(f'<text x="{x0}" y="113" font-size="19" font-weight="bold">{label}  |  {w["terrain"]["counts"]["trees"]} trees</text>')
        parts.append(f'<text x="{x0}" y="138" font-size="14">Discovery days: {days[0]} / {days[1]} / {days[2]}</text>')
        for i, (height, node, top, top_node) in enumerate(w["terrain"]["columns"]):
            z, x = divmod(i, 65)
            color = palette[top_node.removeprefix("rdl_bridge:exploration_")]
            shade = 1 + height*.045
            color = '#'+''.join(f'{min(255,round(c*shade)):02x}' for c in color)
            parts.append(f'<rect x="{x0+x*step}" y="{y0+(64-z)*step}" width="8.1" height="8.1" fill="{color}"/>')
        def point(pos):
            return x0+(pos["x"]+32.5)*step, y0+(32.5-pos["z"])*step
        # Full first day's walk, then first successful route only up to actual discovery.
        routes = [s["days"][0]] + ([s["days"][days[0]-1]] if days[0] != "-" else [])
        for index, day in enumerate(routes):
            world = day["data"]["world"]
            limit = day["receipt"]["metrics"]["first_food_us"] if index else None
            positions = [world["initial_body"]["position"]]+[a["after"]["position"] for a in world["actions"]
                         if limit is None or a["result"]["executed_us"] <= limit]
            points = ' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in positions)
            parts.append(f'<polyline points="{points}" fill="none" stroke="{"#ffffff" if index==0 else "#ffbe46"}" stroke-width="{2 if index==0 else 3}" opacity=".95"/>')
        for pos, color, text in ((w["initial_body"]["position"], "#18362c", "Start"), (w["food_initial"], "#bc3649", "Food")):
            px, py = point(pos)
            parts.append(f'<circle cx="{px}" cy="{py}" r="6" fill="{color}" stroke="white" stroke-width="2"/>')
            parts.append(f'<text x="{px+9}" y="{py-8}" font-size="13" font-weight="bold" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">{text}</text>')
        parts.append(f'<text x="{x0}" y="701" font-size="13">64 x 64 node activity area. Surface height: -3 to +3.</text>')
    parts += ['<rect x="40" y="729" width="22" height="4" fill="#a0a7a2"/>',
              '<text x="73" y="736" font-size="14">White: day 1</text>',
              '<rect x="260" y="729" width="22" height="4" fill="#ffbe46"/>',
              '<text x="294" y="736" font-size="14">Amber: first discovery route (later tested and adopted)</text>',
              '<text x="40" y="771" font-size="13">Green = grass/canopy, brown = soil/trunk, gray = rock, blue = static shallow water. No artificial trail.</text>',
              '</g></svg>']
    Path(output).write_text('\n'.join(parts), encoding='utf-8')


if __name__ == "__main__":
    render(json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes())), sys.argv[2])
