"""Explicit one-task deadline experiment; all action budgets remain unchanged."""
from copy import deepcopy
from .exploration import fields, require
from .goal_reassessment import ReassessingAgent, ReassessingExploration

SCHEMA = 'l15a-task-deadline-v1'


def deadline_loop(seconds):
    require(type(seconds) is int and seconds in (16, 32, 64), 'task_deadline')

    class DeadlineAgent(ReassessingAgent):
        period_us = seconds * 1_000_000

    class DeadlineExploration(ReassessingExploration):
        schema = SCHEMA
        agent_type = DeadlineAgent

        def __init__(self, run_id, periods=1, seed=20260928, assignment='steady'):
            require(periods == 1, 'single_task_required')
            super().__init__(run_id, periods, seed, assignment)

        def dispatch(self, name, value):
            if name == 'configure':
                fields(value, 'schema run_id world_epoch agent_id clock_id teaching selection_profile rest_mode reactivation_mode reassessment_mode task_seconds')
                require(type(value['task_seconds']) is int and value['task_seconds'] == seconds,
                        'task_deadline_conflict')
                response = super().dispatch(name, {k: deepcopy(v) for k, v in value.items() if k != 'task_seconds'})
                return dict(response, task_seconds=seconds)
            return super().dispatch(name, value)

        def snapshot(self):
            with self.lock:
                s = super().snapshot()
                s['period_us'] = seconds * 1_000_000
                return s

    return DeadlineExploration
