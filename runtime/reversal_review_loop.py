"""Explicit opt-in transport for the finite stationary review experiment."""
from copy import deepcopy
from .exploration import fields, require
from .exploration_deadline import deadline_loop


def review_loop(seconds):
    base = deadline_loop(seconds)

    class ReviewAgent(base.agent_type):
        reversal_review_mode = None

    class ReviewLoop(base):
        schema = 'l15a-reversal-review-v1'
        agent_type = ReviewAgent

        def dispatch(self, name, value):
            if name != 'configure':
                return super().dispatch(name, value)
            with self.lock:
                fields(value, 'schema run_id world_epoch agent_id clock_id teaching selection_profile rest_mode reactivation_mode reassessment_mode task_seconds reversal_review_mode')
                mode = value['reversal_review_mode']
                require(mode in ('disabled', 'enabled'), 'reversal_review_mode')
                require(value['agent_id'] in self.agents, 'unknown_agent')
                a = self.agents[value['agent_id']]
                require(a.reversal_review_mode in (None, mode), 'reversal_review_conflict')
                response = super().dispatch(name, {k: deepcopy(v) for k,v in value.items() if k != 'reversal_review_mode'})
                a.reversal_review_mode = mode
                return dict(response, reversal_review_mode=mode)

        def snapshot(self):
            with self.lock:
                s = super().snapshot()
                s['reversal_review_modes'] = {aid: a.reversal_review_mode for aid,a in self.agents.items()}
                return s

    return ReviewLoop
