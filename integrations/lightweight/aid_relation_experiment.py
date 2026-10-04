"""Matched subjective evidence with different experimenter-known hearing conditions."""
from copy import deepcopy
import json
from pathlib import Path
from runtime.aid_relations import AidRelations
from .voice_rescue import RescueWorld,choose


class RelationWorld(RescueWorld):
    def __init__(self,hearing=True):
        super().__init__('aid-relations');self.hearing=hearing
        self.received={a:[] for a in self.agents}

    def observe_rescue(self,aid):
        o=super().observe_rescue(aid)
        if aid=='npc_b' and not self.hearing:
            o['heard']=[]
            # Dedicated receiver impairment: no recognition of a voiced request.
            for contact in o['near']:contact['requesting_help']=False
        o['received_aid']=deepcopy(self.received[aid])
        return o

    def act_rescue(self,aid,operation,action,target=None,angle=0):
        with self.rescue_lock:
            replay=(aid,operation) in self.rescue_receipts
            r=super().act_rescue(aid,operation,action,target,angle)
            if not replay and r['status']=='fed':
                self.received[target].append(dict(giver=aid,time=self.seconds,operation=operation))
            return r


def episode(relations,event,mode):
    if mode not in ('help','decline','unheard'):raise ValueError('mode')
    w=RelationWorld(mode!='unheard');w.objects=[]
    for i,a in enumerate(w.agents.values()):a.update(x=i*.4,z=0.,inventory=0,yaw=0.)
    w.agents['npc_b']['inventory']=2;w.bodies['npc_a']['reserve']=0.
    relations.begin(event,'npc_b',w.observe_rescue('npc_a'),0)
    records=[]
    for t in range(3):
        w.seconds=t
        w.act_rescue('npc_a',f'call:{t}','call')
        observation=w.observe_rescue('npc_b')
        # Explicit experimental refusal, not a learned motive or a fact sent to A.
        decision=dict(action='rest') if mode=='decline' else choose(observation)
        result=w.act_rescue('npc_b',f'reply:{t}',**decision)
        records.append(dict(observation=observation,decision=decision,result=result))
    w.seconds=3
    own=w.observe_rescue('npc_a')
    evidence=relations.finish(event,own,3)
    # Common next-choice fixture: both familiar members are now in visual contact.
    w.agents['npc_c'].update(x=0.,z=.4)
    next_observation=w.observe_rescue('npc_a')
    selected=relations.select(c['ref'] for c in next_observation['near'])
    command=w.act_rescue('npc_a','next-request','call',target=selected)
    return dict(experimenter_mode=mode,helper_records=records,own_evidence=evidence,
                expectations={x:relations.expectation(x) for x in ('npc_b','npc_c')},
                next_expected_helper=selected,next_command=command,
                recipient_body=deepcopy(w.bodies['npc_a']))


def experiment():
    members=('npc_a','npc_b','npc_c');report={}
    for mode in ('help','decline','unheard'):
        a=AidRelations('npc_a',members);b=AidRelations('npc_b',members)
        result=episode(a,'episode-1',mode)
        result['reverse_expectation']=b.expectation('npc_a')
        result['later_help']=episode(a,'episode-2','help')
        report[mode]=result
    return report


if __name__=='__main__':
    report=experiment()
    Path('tests/fixtures/aid_relations.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print({k:(v['expectations'],v['next_expected_helper'],v['later_help']['expectations']) for k,v in report.items()})
