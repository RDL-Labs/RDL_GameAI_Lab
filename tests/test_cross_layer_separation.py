import copy
import itertools
import unittest

from runtime.core import decide_action
from runtime.experience import InteractionHistory
from runtime.history_policy import HistoryInfluencePolicy
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_experience import food_packet, result


class CrossLayerSeparationTests(unittest.TestCase):
    def history(self, outcome):
        history = InteractionHistory()
        if outcome is not None:
            prior = food_packet('past')
            history.register_decision(prior, decide_action(prior))
            history.record_result(result('past', outcome))
        return history

    def test_combined_local_layers_preserve_selected_canonical_path(self):
        """Current local changes must not silently mutate the frozen canonical M_B."""
        reference = None
        actions, expressions = set(), set()
        for outcome, profile, scale in itertools.product(
            (None, 'approach_progress', 'approach_no_progress'),
            ('short', 'standard', 'long'), (0, 0.5, 1),
        ):
            with self.subTest(outcome=outcome, profile=profile, scale=scale):
                history = self.history(outcome)
                history_before = history.snapshot()
                observed = food_packet('current')
                observed['tick'] = 2
                observed['observation']['body'] = {
                    'agent_id': 'npc_a', 'snapshot_id': 'body-current',
                    'revision': 1, 'movement_scale': scale,
                }
                packet_before = copy.deepcopy(observed)
                canonical = GameAIFrozenComparisonSidecar()
                canonical.capture(food_packet('prior'))
                models_before = canonical.snapshot()['models']
                decision = HistoryInfluencePolicy(profiles={'npc_a': profile}).decide(observed, history)
                mismatch = canonical.capture(observed)
                snapshot = canonical.snapshot()
                self.assertEqual(snapshot['models'], models_before)
                self.assertTrue(mismatch.is_zero)
                self.assertEqual(snapshot['assessment']['retained_H'][0]['H'], 0)
                self.assertEqual(snapshot['failures'], [])
                if reference is None:
                    reference = snapshot
                self.assertEqual(snapshot, reference)
                self.assertEqual(observed, packet_before)
                self.assertEqual(history.snapshot(), history_before)
                actions.add(decision['action']['type'])
                expressions.add(decision['inspection']['expression']['label'])
        self.assertEqual(actions, {'approach', 'idle'})
        self.assertEqual(expressions, {'engaged', 'holding', 'restricted'})

    def test_review_changes_h_not_local_decision_or_frozen_model(self):
        canonical = GameAIFrozenComparisonSidecar()
        prior = food_packet('prior')
        prior['observation']['visible_objects'] = []
        canonical.capture(prior)
        observed = food_packet('current')
        observed['tick'] = 2
        canonical.capture(observed)
        before = canonical.snapshot()
        history = self.history('approach_no_progress')
        history_before = history.snapshot()
        decision = HistoryInfluencePolicy(profiles={'npc_a': 'long'}).decide(observed, history)
        record = before['assessment']['records'][0]
        reviewed = canonical.assessments.review({
            'assessment_id': record['assessment_id'], 'expected_revision': 0,
            'reviewer': 'finite-test', 'basis': 'declared residual fixture',
            'evidence': 'prior->current', 'dimensions': {
                'visible_agents_count': {'status': 'zero'},
                'visible_objects_count': {'status': 'unresolved', 'residual': 1},
                'visible_places_count': {'status': 'zero'},
            },
        })
        self.assertEqual(reviewed['H'], 1)
        after = canonical.snapshot()
        self.assertEqual(after['assessment']['retained_H'][0]['H'], 1)
        for field in ('models', 'latest_sections', 'latest_interpretations', 'latest_E'):
            self.assertEqual(before[field], after[field])
        # Fresh policy avoids mistaking a replay-cache hit for independence.
        self.assertEqual(HistoryInfluencePolicy(profiles={'npc_a': 'long'}).decide(observed, history), decision)
        self.assertEqual(history.snapshot(), history_before)

    def test_changed_selected_observation_can_still_form_e(self):
        canonical = GameAIFrozenComparisonSidecar()
        prior = food_packet('prior')
        canonical.capture(prior)
        models = canonical.snapshot()['models']
        later = food_packet('later')
        later['tick'] = 2
        later['observation']['visible_objects'] = []
        mismatch = canonical.capture(later)
        self.assertEqual(mismatch.deltas['visible_objects_count'], -1)
        self.assertEqual(canonical.snapshot()['models'], models)
        self.assertEqual(canonical.assessments.snapshot()['retained_H'][0]['H'], 0)
