"""Measured refusals -> retained H trace -> matched later World interactions."""
import json
from pathlib import Path
from .minimal_communication import CommunicationWorld
from runtime.aid_method_pressure import update
from runtime.refusal_relation_field import compile_field,choose
from runtime.social_sleep import ingest


def world():
    w=CommunicationWorld();w.objects=[]
    for i,a in enumerate(w.agents.values()):a.update(x=i*.2,z=0.,inventory=0)
    return w


def learn(outcome='refuse'):
    w=world();w.agents['npc_b']['inventory']=2;state=None;pressure=None;events=[]
    for i in range(2):
        w.seconds=i*4
        result=w.communicate('npc_a',f'q{i}','request','npc_b')
        state=state or dict(records={},model={},cycles=[],pending=None)
        state['pending']=dict(message_id=f'npc_a:q{i}',operation_id=f'q{i}',target='npc_b',
                              deadline=(w.seconds+3)*1000000,request_observation_id=f'start{i}')
        w.seconds+=1
        response=w.communicate('npc_b',f'r{i}',outcome,'npc_a',f'npc_a:q{i}') if outcome=='refuse' else None
        w.seconds=i*4+3
        packet=dict(agent_id='npc_a',capture_us=w.seconds*1000000,observation_id=f'end{i}',
                    social=w.observe_communication('npc_a'))
        state=ingest(state,packet,{f'q{i}':result})
        pressure=update(pressure,state['records'],'npc_a')
        events.append(dict(request=result,response=response,packet=packet))
    return compile_field(state['records'],pressure,'npc_a'),dict(events=events,records=state['records'],pressure=pressure)


def experiment():
    field,training=learn();empty,_=learn('no_response');cases={}
    for name,enabled,question,affiliation,model,inventory in [
        ('request_control',False,'request_again',0,field,2),('request_trace',True,'request_again',0,field,2),
        ('response_control',False,'respond',0,field,2),('response_trace',True,'respond',0,field,2),
        ('affiliation',True,'respond',2,field,2),('no_response',True,'respond',0,empty,2),
        ('no_food',True,'respond',0,field,0)]:
        runs=[]
        for seed in range(32):
            w=world();w.agents['npc_a']['inventory']=inventory
            w.agents['npc_b']['inventory']=2 if question=='request_again' else 0
            if question=='respond':w.communicate('npc_b','new-request','request','npc_a')
            w.seconds=1;observation=w.observe_communication('npc_a')
            decision,trace=choose(model,observation,'npc_b',question,seed,enabled=enabled,affiliation=affiliation)
            before=sum(a['inventory'] for a in w.agents.values())
            result=w.communicate('npc_a','decision',**decision)
            assert sum(a['inventory'] for a in w.agents.values())==before
            assert w.communicate('npc_a','decision',**decision)==result
            runs.append(dict(observation=observation,trace=trace,result=result))
        cases[name]=dict(runs=runs,selected={action:sum(r['trace']['selected']==action for r in runs)
                                          for action in ('request','wait','give','refuse')})
    return dict(training=training,field=field,cases=cases)


if __name__=='__main__':
    report=experiment()
    Path('tests/fixtures/refusal_field.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print({k:v['selected'] for k,v in report['cases'].items()})
