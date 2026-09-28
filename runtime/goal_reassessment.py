"""One extra observed subgoal per period, after rest and exhausted legacy budget."""
from copy import deepcopy
from math import isclose
from .exploration import fields, require
from .landmark_exploration import center, MAX_GOALS
from .rest_reactivation import ReactivatingAgent, ReactivatingExploration, appearance_key

SCHEMA = 'l15a-goal-reassessment-v1'


def candidates(packet, held, evaluation):
    """Conservative color exclusion is not object identity or learned value."""
    if appearance_key(packet) is None:
        return [], 'acquisition_incomplete'
    if not held or not held.get('current_feature'):
        return [], 'held_descriptor_unavailable'
    color=held['current_feature']['color']
    penalty=evaluation['forward_penalty'] if evaluation else 0.
    rows=[]
    for f in packet['landmarks']['features']:
        reasons=[]
        if f['color']==color:reasons.append('held_color_excluded')
        if f['range_band']=='near':reasons.append('near_feature')
        if f['azimuth'][1]-f['azimuth'][0]>45:reasons.append('wide_feature')
        frontal=f['azimuth'][0]<=0<=f['azimuth'][1]
        base=abs(center(f))/90
        rows.append(dict(feature=deepcopy(f),reasons=reasons,base_cost=base,
            episodic_cost=penalty if frontal else 0.,cost=base+(penalty if frontal else 0.)))
    return rows, None


class ReassessingAgent(ReactivatingAgent):
    reassessment_mode=None

    def _decision(self,p):
        d=super()._decision(p)
        previous=next(reversed(self.decisions.values())) if self.decisions else None
        old=previous.get('goal_reassessment') if previous and previous['period']==d['period'] else None
        state=deepcopy(old['state']) if old else dict(used=False,held=None,source=None,selected=None)
        meta=dict(mode=self.reassessment_mode,state=state,triggered=False,status='inactive',
                  candidates=[],baseline_action=list(d['action']),baseline_reason=d['reason'])
        d['goal_reassessment']=meta
        if self.reassessment_mode!='enabled' or state['used']:
            return d
        if d['reason']!='landmark_goal_budget' or d['rest']['transition']!='resumed':
            return d
        # Consume even an empty review; no repeated draws or budget resets.
        held=deepcopy(d['landmark']['goal'])
        state.update(used=True,held=held,source=p['observation_id'])
        rows,error=candidates(p,held,d['reactivation']['evaluation'])
        meta.update(triggered=True,candidates=rows,status=error or 'no_candidate')
        eligible=[r for r in rows if not r['reasons']]
        if not eligible:return d
        # Fixed current-angle effort ranking. Memory is a separate sourced cost.
        minimum=min(r['cost'] for r in eligible)
        best=[r for r in eligible if isclose(r['cost'],minimum,abs_tol=1e-9)]
        if len(best)!=1:
            meta['status']='ambiguous_minimum';return d
        chosen=best[0]
        f=chosen['feature'];state['selected']=deepcopy(f);meta['status']='selected'
        assert d['landmark']['selected_count']==MAX_GOALS
        d['landmark'].update(stage='active',outcome=None,selection_index=None,goal=dict(
            goal_id=p['observation_id']+':review-goal',source_observation=p['observation_id'],
            source_feature=f['ref'],source_pose=p['pose_ref'],source_capture_us=p['capture_us'],
            operations=0,current_feature=deepcopy(f),current_observation=p['observation_id'],current_pose=p['pose_ref']))
        angle=center(f)
        action=['turn',max(-45,min(45,int(round(angle/5))*5))] if abs(angle)>7.5 else ['move',1]
        d.update(action=action,target='',reason='goal_reassessment_selected')
        return d

    def snapshot(self):
        s=super().snapshot();s.update(movement_control=SCHEMA,reassessment_mode=self.reassessment_mode);return s


class ReassessingExploration(ReactivatingExploration):
    schema=SCHEMA
    agent_type=ReassessingAgent

    def dispatch(self,name,value):
        if name!='configure':return super().dispatch(name,value)
        with self.lock:
            fields(value,'schema run_id world_epoch agent_id clock_id teaching selection_profile rest_mode reactivation_mode reassessment_mode')
            mode=value['reassessment_mode']
            require(mode in ('disabled','enabled'),'reassessment_mode')
            require(value['agent_id'] in self.agents,'unknown_agent')
            a=self.agents[value['agent_id']]
            require(a.reassessment_mode in (None,mode),'reassessment_configuration_conflict')
            response=super().dispatch(name,{k:deepcopy(v) for k,v in value.items() if k!='reassessment_mode'})
            a.reassessment_mode=mode
            return dict(response,reassessment_mode=mode)
