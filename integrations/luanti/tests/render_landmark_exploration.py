"""Readback terrain and actual walks; experimenter diagram, never an agent map."""
import gzip
import json
from pathlib import Path
from html import escape


def render(matrix, output, *, title="L13U / Walking toward observed surface patches", conclusion="Holding a subgoal does not establish a Food route. Failed discovery remains failed discovery."):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="910" viewBox="0 0 1200 910">',
             '<rect width="1200" height="910" fill="#f4f3ed"/>',
             '<g font-family="Arial,sans-serif" fill="#23352e">',
             f'<text x="40" y="44" font-size="25" font-weight="bold">{escape(title)}</text>',
             '<text x="40" y="73" font-size="14">Actual terrain readback and measured movement. Experimenter view; this map is never an agent input.</text>']
    palette = dict(grass=(119,147,83), dirt=(153,124,86), stone=(111,116,111),
                   trunk=(101,72,43), leaves=(51,91,57), water=(87,150,174))
    for panel, series in enumerate(matrix["series"]):
        x0, y0, step = 40+600*panel, 165, 8
        first = series["days"][0]["data"]; world = first["world"]
        summary = series["state"]["summary"]
        label = "MEADOW" if series["scenario"] == "natural_meadow" else "WOODLAND"
        parts.append(f'<text x="{x0}" y="117" font-size="19" font-weight="bold">{label} / {world["terrain"]["counts"]["trees"]} trees</text>')
        parts.append(f'<text x="{x0}" y="144" font-size="14">{len(series["days"])} days / {summary["discovery_count"]} discovery days / model adopted: {str(summary["adopted"]).lower()}</text>')
        for i, (height, node, top, top_node) in enumerate(world["terrain"]["columns"]):
            z, x = divmod(i, 65)
            color = palette[top_node.removeprefix("rdl_bridge:exploration_")]
            color = '#'+''.join(f'{min(255,round(c*(1+height*.045))):02x}' for c in color)
            parts.append(f'<rect x="{x0+x*step}" y="{y0+(64-z)*step}" width="8.1" height="8.1" fill="{color}"/>')
        def point(pos):
            return x0+(pos["x"]+32.5)*step, y0+(32.5-pos["z"])*step
        for day in series["days"]:
            w = day["data"]["world"]
            path = [w["initial_body"]["position"]]+[a["after"]["position"] for a in w["actions"]]
            coords = ' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in path)
            parts.append(f'<polyline points="{coords}" fill="none" stroke="#faf9ec" stroke-width="1.2" opacity=".32"/>')
        path = [world["initial_body"]["position"]]+[a["after"]["position"] for a in world["actions"]]
        coords = ' '.join(f'{point(p)[0]:.2f},{point(p)[1]:.2f}' for p in path)
        parts.append(f'<polyline points="{coords}" fill="none" stroke="#ffd052" stroke-width="2.8"/>')
        # Dots mark where a subgoal was selected, never an inferred target position.
        for obs in world["observations"]:
            st = first["runtime"]["exploration"]["decisions"][obs["packet"]["observation_id"]]["landmark"]
            if st["selection_index"] is None: continue
            x, y = point(obs["body"]["position"])
            parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3.5" fill="#23352e" stroke="#ffd052" stroke-width="1.4"/>')
        food_markers = ([(f["position"], "#bc3649", f"Food {i+1}") for i,f in enumerate(world["foods_initial"])]
                        if "foods_initial" in world else [(world["food_initial"], "#bc3649", "Food")])
        for pos, color, text in [(world["initial_body"]["position"], "#18362c", "Start")]+food_markers:
            x, y = point(pos)
            parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="6" fill="{color}" stroke="white" stroke-width="2"/>')
            parts.append(f'<text x="{x+9:.2f}" y="{y-8:.2f}" font-size="13" font-weight="bold" stroke="#f4f3ed" stroke-width="3" paint-order="stroke">{text}</text>')
        parts.append(f'<text x="{x0}" y="711" font-size="13">64 x 64 node activity area. Each day starts from the same place.</text>')
    parts += ['<text x="40" y="754" font-size="15">Faint white: all days. Amber: day 1. Dots: body positions at subgoal selection on day 1.</text>',
              '<text x="40" y="785" font-size="14">Observed patch → measured turn / step → reobserve → continue, or stop with a recorded reason.</text>',
              '<text x="40" y="821" font-size="14">Brown / gray / green patches are coarse visual records. They are not persistent tree or rock identities.</text>',
              f'<text x="40" y="855" font-size="14">{escape(conclusion)}</text>',
              '</g></svg>']
    Path(output).write_text('\n'.join(parts), encoding='utf-8')


if __name__ == "__main__":
    import sys
    render(json.loads(gzip.decompress(Path(sys.argv[1]).read_bytes())), sys.argv[2])
