"""Seeded outer landscape around the existing camp; experimenter-only placement."""
from random import Random
from math import sin,cos,radians,hypot

RULE='expanded-camp-landscape-v1'


def extend(world):
    rng=Random(f'{RULE}:{world.seed}')
    # Retain camp, nearby resources and starting bodies exactly as configured.
    for i,distance in enumerate((16,24,32,40,56,64,80,96)):
        angle=radians(i*137.5+rng.uniform(-12,12))
        x,z=sin(angle)*distance,6+cos(angle)*distance
        world.resources.append(dict(x=x,z=z,stock=12))
        world.objects.append(dict(x=x+2,z=z,radius=.65,height=rng.choice((5.,8.,12.)),
                                  color=rng.choice(('brown','green','gray')),solid=True))
    added=0
    for i in range(128):
        if added==16:break
        angle=radians(rng.uniform(-180,180));distance=rng.uniform(14,96)
        obj=dict(x=sin(angle)*distance,z=6+cos(angle)*distance,
            radius=rng.uniform(.5,1.2),height=rng.choice((2.,5.,8.,16.)),
            color=rng.choice(('brown','green','gray')),solid=True)
        if any(hypot(obj['x']-r['x'],obj['z']-r['z'])<=obj['radius']+.5 for r in world.resources):continue
        world.objects.append(obj);added+=1


def render_layout(manifest,path):
    """World truth for the experimenter, never sent to an individual."""
    objects=manifest['objects'];resources=manifest['resources']
    def xy(x,z):return 340+x*3,340-(z-6)*3
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="680" height="720" viewBox="0 0 680 720">',
        '<rect width="680" height="720" fill="#e6efda"/>',
        '<text x="20" y="25" font-family="sans-serif">LW expanded World / outer resource radius 96 m</text>']
    for radius in (24,48,96):
        parts.append(f'<circle cx="340" cy="340" r="{radius*3}" fill="none" stroke="#b6c6ac" stroke-dasharray="4 4"/>')
        parts.append(f'<text x="{345+radius*3}" y="335" font-size="11">{radius}m</text>')
    for o in objects:
        x,y=xy(o['x'],o['z']);parts.append(f'<circle cx="{x}" cy="{y}" r="{max(3,o["radius"]*3)}" fill="#7b8073"/>')
    for r in resources:
        x,y=xy(r['x'],r['z']);parts.append(f'<circle cx="{x}" cy="{y}" r="4" fill="#bd772a"><title>Food stock {r["stock"]}</title></circle>')
    parts.append('<rect x="335" y="335" width="10" height="10" fill="#26517b"/><text x="20" y="698" font-family="sans-serif">Blue: camp / brown: food / gray: landmarks &amp; obstacles. World truth, not agent input.</text></svg>')
    path.write_text('\n'.join(parts),encoding='utf8')
    path.with_suffix('.html').write_text('<!doctype html><meta charset="utf-8">'+'\n'.join(parts),encoding='utf8')
