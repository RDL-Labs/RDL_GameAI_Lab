"""Body contributions to already feasible local methods, not new goal authority."""
from .hunger_review import update


def apply(agent, packet, selection, phase):
    candidates=selection['candidates']
    key=lambda c:(-c['score'],c['last_selected'],c['model'])
    baseline=min(candidates,key=key)['model']
    trace=dict(rule='body-method-field-v1',applied=False,contributions=[],baseline=baseline,
               selected=baseline,changed=False)
    if phase not in ('exploration','return') or selection['gate']!='method_reselection':
        trace['reason']='protected_phase_or_proposal';return trace
    body=packet['social']['body']
    hunger=update(agent.learning.get('hunger'),agent.agent_id,packet['capture_us'],
                  body['reserve'],packet['observation_id'])
    urgency=hunger['intensity']*(1+min(1,hunger['goal']['H']/hunger['goal']['threshold']))
    fatigue=body['strain']
    # Depletion cannot be repaired by rest; never reward rest as a food result.
    recoverable=min(1,body['reserve']/20)
    for candidate in candidates:
        if not candidate.get('record_trial',True):continue
        action=candidate['action'][0]
        if action=='wait':
            delta=fatigue*recoverable-urgency*.5
        elif action in ('move','turn'):
            delta=urgency*.5-fatigue*.5
        else:continue
        before=candidate['score'];candidate['score']+=delta
        trace['contributions'].append(dict(model=candidate['model'],before=before,
            delta=delta,after=candidate['score']))
    chosen=min(candidates,key=key)['model']
    trace.update(applied=bool(trace['contributions']),selected=chosen,changed=chosen!=baseline,
        urgency=urgency,fatigue=fatigue,hunger_H=hunger['goal']['H'],reason='existing_methods_only')
    return trace
