"""Small seeded riparian landscape. Global geometry is World-only."""
from math import sin, hypot
from random import Random
from pathlib import Path
import json

RULE='lw-riparian-base-v1'

class Landscape:
    def __init__(self,seed):
        self.seed=seed
        rng=Random(f'{RULE}:{seed}')
        self.phase=rng.uniform(-.4,.4)

    def river(self,z):
        return 12+5*sin((z-6)/22+self.phase)

    def width(self,z):
        return 1.2+.4*(1+sin(z/13))

    def material(self,x,z):
        d=abs(x-self.river(z))
        if d<=self.width(z)/2:return 'water'
        if d<4:return 'bank'
        if ((x+28)/18)**2+((z-28)/24)**2<1 or ((x-37)/17)**2+((z+20)/25)**2<1:return 'forest'
        if ((x+23)/13)**2+((z+25)/15)**2<1:return 'rockland'
        return 'grassland'

    def resistance(self,x,z):
        return {'water':3.,'bank':1.8,'forest':2.,'rockland':2.5,'grassland':1.5}[self.material(x,z)]

    def dry(self,x,z):return self.material(x,z)!='water'

    def metadata(self):return dict(rule=RULE,seed=self.seed,phase=self.phase,extent=[-64,64,-58,70],camp=[0,6])


def install(world):
    land=Landscape(world.seed);world.landscape=land
    world.ground_wear.walkable_surface=land.dry
    world.objects=[dict(x=0.,z=8.,radius=.3,height=12.,color='ochre',solid=True)]
    world.resources=[];rng=Random(f'{RULE}:objects:{world.seed}')
    for _ in range(1800):
        if len(world.objects)>=100:break
        x,z=rng.uniform(-60,60),rng.uniform(-54,66);m=land.material(x,z)
        probability={'forest':.75,'bank':.10,'grassland':.035,'rockland':.65,'water':0}[m]
        if rng.random()>probability or hypot(x,z-6)<5:continue
        radius=.6 if m!='rockland' else rng.uniform(.4,.9)
        if any(hypot(x-o['x'],z-o['z'])<radius+o['radius']+1 for o in world.objects):continue
        world.objects.append(dict(x=x,z=z,radius=radius,height=rng.uniform(5,9) if m!='rockland' else rng.choice((.4,2.,3.)),
                                  color='brown' if m!='rockland' else 'gray',solid=True))
    # Only some forest trees bear resources. Other trees share the same appearance.
    for o in world.objects:
        x,z=o['x']+1.5,o['z']
        if o['color']!='brown' or land.material(o['x'],o['z'])!='forest' or hypot(x,z-6)<16:continue
        if not land.dry(x,z) or any(hypot(x-q['x'],z-q['z'])<q['radius']+.5 for q in world.objects):continue
        world.resources.append(dict(x=x,z=z,stock=12))
        if len(world.resources)==10:break
    if len(world.resources)!=10:raise ValueError('landscape_resource_placement')
    return land


def render(world,path):
    land=world.landscape;colors={'water':'#6bb6d2','bank':'#b7d39a','forest':'#71995d','rockland':'#aaa99a','grassland':'#d3dfa4'}
    def xy(x,z):return 32+(x+64)*5,48+(70-z)*5
    parts=['<svg xmlns="http://www.w3.org/2000/svg" width="704" height="740" viewBox="0 0 704 740"><rect width="704" height="740" fill="#f5f1e7"/><text x="32" y="28" font-family="sans-serif">LW base landscape / 128 m view / seed '+str(world.seed)+'</text>']
    for x in range(-64,64):
        for z in range(-58,70):
            px,py=xy(x,z+1);color=colors[land.material(x+.5,z+.5)]
            parts.append(f'<rect x="{px}" y="{py}" width="5.1" height="5.1" fill="{color}"/>')
    for o in world.objects:
        x,y=xy(o['x'],o['z']);color='#3c633b' if o['color']=='brown' else '#66665c'
        parts.append(f'<circle cx="{x}" cy="{y}" r="{max(2,o["radius"]*5)}" fill="{color}"/>')
    for o in world.resources:
        x,y=xy(o['x'],o['z']);parts.append(f'<circle cx="{x}" cy="{y}" r="3" fill="#e59a29"/>')
    x,y=xy(0,6);parts.append(f'<rect x="{x-5}" y="{y-5}" width="10" height="10" fill="#653d7a"/><text x="{x+9}" y="{y}">Camp</text>')
    parts.append('<text x="32" y="714" font-family="sans-serif" font-size="12">Blue: stream / dark green: forest / gray: rockland / orange: resources</text><text x="32" y="732" font-size="12">World truth for inspection; not an agent map. No boundary wall at view edge.</text></svg>')
    Path(path).write_text('<!doctype html><meta charset="utf-8">'+''.join(parts),encoding='utf8')

if __name__=='__main__':
    from .energy_exploration import EnergyWorld
    w=EnergyWorld('base-preview',seed=20261005);install(w)
    root=Path('outputs/base_landscape');root.mkdir(parents=True,exist_ok=True)
    render(w,root/'map.html')
    (root/'layout.json').write_text(json.dumps(dict(landscape=w.landscape.metadata(),objects=w.objects,resources=w.resources),indent=2),encoding='utf8')
