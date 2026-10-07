import os
import subprocess
import sys
import unittest

class TimeProfileTests(unittest.TestCase):
    def test_scaled_process_contract(self):
        code="""
from runtime.lw_time import *
from runtime.landmark_day_cycle import phase
from runtime.layered_body import initial,step,capabilities
from integrations.lightweight.resource_regrowth import ResourceRegrowth
from integrations.lightweight.ground_wear import GroundWear
from integrations.lightweight.social_life import SocialWorld
from integrations.lightweight.cohort_world import restore
from runtime.initial_orientation import sample,validate
assert DAY_US*5==86400*1000000
assert [phase(t) for t in (0,BOUNDARIES[0],BOUNDARIES[1],BOUNDARIES[2],DAY_US)]==['orientation','exploration','return','night','orientation']
assert ResourceRegrowth(3).period==3*DAY_US
w=SocialWorld('scaled-test');w.advance_metabolism(DAY_US)
assert abs(w.bodies['npc_a']['reserve']-84)<1e-8
p=w.packet('npc_a',0)
assert p['locomotor']['state']['rule']=='layered-body-human-scale-v1'
s=initial();after,r=step(s,'walk',resistance=1.5)
assert abs(r['distance']-.5)<1e-8
assert abs(r['delta']['reserve']+.15/270)<1e-8
assert abs(r['delta']['strain']-.045/60)<1e-8
assert capabilities(dict(s,reserve=.001),resistance=1.5)['can_walk']
g=GroundWear();g.recovery_enabled=True;g.walk('a','a',(0,0),(1,0));before=sum(c['wear'] for c in g.cells.values())
g.advance(DAY_US);assert sum(c['wear'] for c in g.cells.values())==before
g.advance(2*DAY_US);assert sum(c['wear'] for c in g.cells.values())==0
try:restore(w,None,None,None,{'time_profile':{'profile':'legacy'}})
except ValueError as e:assert str(e)=='checkpoint_time_profile'
else:raise AssertionError('cross-profile restore')
print('scaled contract PASS')
"""
        # An isolated process prevents profile changes halfway through a run.
        result=subprocess.run([sys.executable,'-c',code],env=dict(os.environ,RDL_LW_TIME_PROFILE='human_scale_v1'),capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)

    def test_default_legacy_unchanged(self):
        from runtime.lw_time import DAY_US,BOUNDARIES
        self.assertEqual(DAY_US,64000000);self.assertEqual(BOUNDARIES,(1000000,32000000,56000000,64000000))
