"""Finite, directional aid expectations from own observations; no intent inference."""
from copy import deepcopy


class AidRelations:
    def __init__(self,owner,members):
        if owner not in members or len(set(members))!=len(members):raise ValueError('membership')
        self.owner=owner;self.members=tuple(members)
        self.evidence={};self.pending={}

    def expectation(self,other):
        if other==self.owner or other not in self.members:raise ValueError('relation_target')
        records=[r for r in self.evidence.values() if r['expected_helper']==other]
        # Shared-base prior is one positive and one negative pseudo-count, not Experience.
        return (1+sum(r['outcome']=='aid_observed' for r in records))/(2+len(records))

    def begin(self,event,target,observation,now):
        if target not in {c['ref'] for c in observation['near']}:raise ValueError('unobserved_target')
        record=dict(expected_helper=target,start=now,deadline=now+3,expectation=self.expectation(target))
        if event in self.evidence:raise ValueError('closed_request')
        if event in self.pending:
            if self.pending[event]!=record:raise ValueError('request_conflict')
            return
        if len(self.pending)+len(self.evidence)>=16:raise ValueError('relation_capacity')
        self.pending[event]=record

    def finish(self,event,observation,now):
        if event in self.evidence:return deepcopy(self.evidence[event])
        request=self.pending[event]
        if now<request['deadline']:raise ValueError('request_pending')
        received=[x for x in observation['received_aid'] if x['giver']==request['expected_helper']
                  and request['start']<=x['time']<request['deadline']]
        result=dict(request,outcome='aid_observed' if received else 'no_aid_observed',
                    received_aid=deepcopy(received),intent='unknown',owner=self.owner)
        self.evidence[event]=result;del self.pending[event]
        return deepcopy(result)

    def select(self,visible):
        candidates=sorted(set(visible)&(set(self.members)-{self.owner}))
        return min(candidates,key=lambda x:(-self.expectation(x),x)) if candidates else None
