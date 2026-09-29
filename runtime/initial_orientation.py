"""Initial coarse sky orientation; no position, destination or route knowledge."""
from math import floor, isfinite
from collections import deque

MODEL = 'initial-sky-orientation-v1'
SOURCE = ('run_id', 'agent_id', 'observation_id', 'capture_us', 'pose_ref')

def sample(packet, yaw, available=True):
    if not isfinite(yaw):
        raise ValueError('orientation_yaw')
    # Fixed quantization, not independent noise that repeated samples average away.
    center = (floor((-yaw + 15) / 30) * 30 + 180) % 360 - 180
    return dict(model=MODEL, source={k:packet[k] for k in SOURCE},
                reference='world-fixed-bearing-zero', status='available' if available else 'unavailable',
                relative_center=center if available else None, half_width=15,
                cue='stars_equivalent' if packet['capture_us'] % 64000000 >= 56000000 else 'sun_shadow_equivalent',
                environment='ideal-sky-no-occlusion')

def validate(packet):
    x=packet['orientation']
    if set(x) != {'model','source','reference','status','relative_center','half_width','cue','environment'}:
        raise ValueError('orientation_fields')
    if x['model']!=MODEL or x['source']!={k:packet[k] for k in SOURCE}:
        raise ValueError('orientation_binding')
    if x['reference']!='world-fixed-bearing-zero' or x['half_width']!=15 or x['environment']!='ideal-sky-no-occlusion':
        raise ValueError('orientation_rule')
    expected='stars_equivalent' if packet['capture_us']%64000000>=56000000 else 'sun_shadow_equivalent'
    if x['cue']!=expected:raise ValueError('orientation_cue')
    if x['status']=='unavailable':
        if x['relative_center'] is not None:raise ValueError('orientation_unavailable')
    elif x['status']!='available' or type(x['relative_center']) not in (int,float) or x['relative_center'] not in range(-180,180,30):
        raise ValueError('orientation_angle')

def scan(packet, observations):
    """Choose only the sign of an already authorized 90-degree rescan.

    Counts at most 256 same-day observations. No goal, move or extra scan authority.
    """
    validate(packet)
    cue=packet['orientation']
    trace=dict(rule=MODEL, applied=False, reason='unavailable', source=cue['source'])
    if cue['status']!='available':return 90,trace
    counts=[0]*12
    records=list(deque(observations,maxlen=256))+[packet]
    for old in records:
        if old['capture_us']>packet['capture_us'] or old['capture_us']//64000000!=packet['capture_us']//64000000:continue
        if old['run_id']!=packet['run_id'] or old['agent_id']!=packet['agent_id']:continue
        if 'orientation' not in old:continue
        validate(old)
        o=old['orientation']
        if o['status']=='available':counts[int((-o['relative_center'])%360//30)]+=1
    heading=(-cue['relative_center'])%360
    left=counts[int((heading-90)%360//30)]
    right=counts[int((heading+90)%360//30)]
    angle=-90 if left<right else 90
    trace.update(applied=True,reason='least_sampled_heading',counts=counts,left_count=left,right_count=right,turn=angle)
    return angle,trace
