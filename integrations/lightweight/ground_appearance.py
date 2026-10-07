"""Finite egocentric ground appearance, independent of route choice."""
from math import floor
from runtime.exploration import require
from .world import segment_hit

ANGLES=(-90,-45,0,45,90)
DISTANCES=(1,2,4)
SOURCE=('run_id','world_epoch','agent_id','observation_id','clock_id','capture_us','pose_ref','body_revision')


def sample(world,aid,p):
    a=world.agents[aid];cells=[]
    for angle in ANGLES:
        dx,dz=world.direction(aid,angle)
        for distance in DISTANCES:
            x,z=a['x']+dx*distance,a['z']+dz*distance
            # Conservative ground visibility: any existing obstacle footprint occludes.
            blocked=any(segment_hit((a['x'],a['z']),(x,z),o) for o in world.objects)
            wear=world.ground_wear.cells.get(f'{floor(x)},{floor(z)}',{}).get('wear',0)
            cells.append(dict(angle=angle,distance=distance,status='occluded' if blocked else 'sampled',
                appearance=None if blocked else 'bare_ground' if wear>=10 else 'trampled_grass' if wear>0 else 'grass'))
    return dict(rule='local-ground-appearance-v1',source={k:p[k] for k in SOURCE},
        coverage='partial' if any(c['status']=='occluded' for c in cells) else 'complete',cells=cells)


def validate(value,p):
    require(set(value)=={'rule','source','coverage','cells'},'ground_appearance_fields')
    require(value['rule']=='local-ground-appearance-v1','ground_appearance_rule')
    require(value['source']=={k:p[k] for k in SOURCE},'ground_appearance_binding')
    require(type(value['cells']) is list and len(value['cells'])==15,'ground_appearance_budget')
    for cell,(angle,distance) in zip(value['cells'],((a,d) for a in ANGLES for d in DISTANCES)):
        require(set(cell)=={'angle','distance','status','appearance'},'ground_appearance_cell')
        require(cell['angle']==angle and cell['distance']==distance,'ground_appearance_ray')
        require((cell['status']=='occluded' and cell['appearance'] is None) or
            (cell['status']=='sampled' and cell['appearance'] in ('grass','trampled_grass','bare_ground')),'ground_appearance_status')
    expected='partial' if any(c['status']=='occluded' for c in value['cells']) else 'complete'
    require(value['coverage']==expected,'ground_appearance_coverage')
