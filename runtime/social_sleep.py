"""Own request outcomes consolidated only on a completed existing Sleep cycle."""
from copy import deepcopy


def ingest(state,packet,results):
    s=deepcopy(state) if state else dict(records={},pending=None,model={},cycles=[])
    now=packet['capture_us'];social=packet['social'];pending=s['pending']
    if pending:
        messages=[m for m in social['messages'] if m['reply_to']==pending['message_id']
                  and m['sender']==pending['target'] and m['kind'] in ('given','refuse')
                  and m['time']*1e6<pending['deadline']]
        response=messages[0] if messages else None
        own_result=results.get(pending['operation_id'])
        if response or now>=pending['deadline']:
            if len(s['records'])>=192:raise ValueError('social_experience_capacity')
            s['records'][pending['message_id']]=dict(pending,agent_id=packet['agent_id'],
                outcome=('request_not_executed' if not own_result or own_result['status']!='expressed'
                         else response['kind'] if response else 'no_response_observed'),
                source_observation_id=packet['observation_id'],tick=now,intent='unknown')
            s['pending']=None
    return s


def consolidate(state,cycle,agent_id):
    s=deepcopy(state)
    if not cycle or cycle['status']!='completed' or cycle['day'] in s['cycles']:return s
    records=list(s['records'].values())
    if any(r['agent_id']!=agent_id for r in records):raise ValueError('social_source_agent')
    # Use only evidence already available at the start of this Sleep.
    records=[r for r in records if r['tick']<=cycle['formation_us'] and r['outcome']!='request_not_executed']
    for target in sorted({r['target'] for r in records}):
        group=[r for r in records if r['target']==target]
        s['model'][target]=dict(expectation=(1+sum(r['outcome']=='given' for r in group))/(2+len(group)),
            sources=[r['message_id'] for r in group],authority='unvalidated local aid expectation; not intent or canonical T1')
    s['cycles'].append(cycle['day'])
    return s

