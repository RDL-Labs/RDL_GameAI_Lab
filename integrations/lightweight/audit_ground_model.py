"""Rebuild each tentative model solely from saved observations and body results."""
import json
from pathlib import Path
from runtime.ground_continuity import update


def main(root=Path('outputs/ground_model')):
    states={};commands={};results={};count=0;max_models=0;executed=[]
    for line in (root/'enabled.jsonl').open(encoding='utf8'):
        row=json.loads(line)
        if row['type']=='completed':
            results[row['command']['operation_id']]=row['result']
            if row['command']['reason'].startswith('continuous_food/ground_'):
                executed.append(dict(command=row['command'],result=row['result']))
        if row['type']!='decision':continue
        p=row['packet'];aid=p['agent_id'];r=results.get(commands.get(aid))
        state=update(p,states.get(aid),r)
        assert state==row['ground_continuity'],'saved_model_replay_difference'
        assert len(state['models'])<=8
        max_models=max(max_models,len(state['models']))
        states[aid]=state;commands[aid]=row['command']['operation_id'];count+=1
    out=dict(replayed_decisions=count,all_models_reproduced=True,max_active_models=max_models,executed_ground_methods=executed)
    (root/'replay.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf8')
    print(json.dumps(out,indent=2))

if __name__=='__main__':main()
