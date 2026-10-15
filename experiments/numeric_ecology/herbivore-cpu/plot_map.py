import csv, json, math, colorsys
from pathlib import Path
root=Path(__file__).resolve().parent
spec=json.loads((root/'map-spec.json').read_text(encoding='utf-8-sig'))
result=json.loads((root/'run/result.json').read_text())
cells=list(csv.DictReader((root/'run/grass.csv').open()))
tracks={i:[] for i in range(1,31)}
for row in csv.DictReader((root/'run/trajectory.csv').open()):
    tracks[int(row['id'])].append((float(row['x']),float(row['z'])))
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="740" viewBox="0 0 1200 740">',
     '<rect width="1200" height="740" fill="#f6f8f5"/>',
     '<g font-family="Yu Gothic,Meiryo,sans-serif" fill="#203127">',
     '<text x="36" y="40" font-size="24">同じマップに草を配置：草食動物30体・3日</text>',
     '<text x="36" y="69" font-size="15">深い記憶なし／採食・探索・休息・睡眠／捕食者なしの基準ケース</text>']
materials={1:'#86c6e5',2:'#e2ddae',3:'#9ebc98',4:'#c1c3c5',5:'#d9e8bc'}
for index,(bounds,title) in enumerate([((-64,64,-58,70),'全体：既存の地形・障害物と草の配置'),((-14,18,-10,22),'開始地点周辺：3日後の草と移動経路')]):
    left=36+index*590; top=126; side=538
    xmin,xmax,zmin,zmax=bounds; scale=side/(xmax-xmin)
    def xy(x,z): return left+(x-xmin)*scale,top+(zmax-z)*scale
    svg.append(f'<text x="{left}" y="108" font-size="18">{title}</text>')
    svg.append(f'<defs><clipPath id="panel{index}"><rect x="{left}" y="{top}" width="{side}" height="{side}"/></clipPath></defs>')
    svg.append(f'<g clip-path="url(#panel{index})">')
    for row in cells:
        x,z=float(row['x']),float(row['z']); px,py=xy(x-1,z+1)
        if x+1<xmin or x-1>xmax or z+1<zmin or z-1>zmax: continue
        m=int(row['material']); cap=float(row['capacity']); final=float(row['final'])
        svg.append(f'<rect x="{px:.2f}" y="{py:.2f}" width="{2*scale+.1:.2f}" height="{2*scale+.1:.2f}" fill="{materials[m]}"/>')
        if cap>0:
            amount=1 if index==0 else max(0,final/cap)
            cx,cy=xy(x,z); radius=scale*.65*math.sqrt(amount)
            svg.append(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{radius:.2f}" fill="#489849" opacity=".7"/>')
    phase=spec['scene']['landscape']['phase']
    zs=[-58+i*.5 for i in range(257)]
    bank=[]
    for sign,order in [(1,zs),(-1,zs[::-1])]:
        for z in order:
            river=12+5*math.sin((z-6)/22+phase); width=1.2+.4*(1+math.sin(z/13))
            bank.append(xy(river+sign*width/2,z))
    svg.append('<polygon points="'+' '.join(f'{x:.2f},{y:.2f}' for x,y in bank)+'" fill="#6ab6d8"/>')
    for o in spec['scene']['obstacles']+spec['scene']['low_obstacles']:
        if not o.get('solid',True): continue
        cx,cy=xy(o['x'],o['z'])
        svg.append(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{o["radius"]*scale:.2f}" fill="#4f5552"/>')
    for i,path in tracks.items():
        color='#'+''.join(f'{round(c*255):02x}' for c in colorsys.hsv_to_rgb((i*.618)%1,.8,.75))
        points=' '.join(f'{x:.2f},{y:.2f}' for x,y in [xy(*p) for p in path])
        svg.append(f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="{.8 if index==0 else 1.2}" opacity=".65"/>')
        p=result['final'][i-1]; x,y=xy(p['x'],p['z'])
        svg.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{2 if index==0 else 3}" fill="{color}" stroke="white" stroke-width=".6"/>')
    svg.append('</g>')
    svg.append(f'<rect x="{left}" y="{top}" width="{side}" height="{side}" fill="none" stroke="#7b8a7b"/>')
svg.extend(['<text x="36" y="695" font-size="15">緑の円：草（右図は残量）　青：川　灰：固体障害物　色線：60秒間隔の位置記録　色点：最終位置</text>',
            '<text x="36" y="721" font-size="14">地形は既存のriparianマップ。栄養・睡眠・再生速度は仮設定で、実際の兎の生理を再現したものではありません。</text>',
            '</g></svg>'])
(root/'map-overview.svg').write_text('\n'.join(svg),encoding='utf-8')
print('Grass cells:',result['grass_cells'],'/',result['cells'])
print('State percentages:',dict(zip(result['state_names'],[round(x/result['agent_updates']*100,2) for x in result['daily'][-1]['state_ticks']])))
print('Final distance min/max:',min(x['distance'] for x in result['final']),max(x['distance'] for x in result['final']))
