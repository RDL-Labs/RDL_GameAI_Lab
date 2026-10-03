from copy import deepcopy
import unittest

from test_multi_resource_exploration import Session
from runtime.harvest_sleep import review
from runtime.sleep_relation_review import prepare, inspect
from integrations.lightweight.world import World
from integrations.lightweight.timed_harvest import HarvestCampaign


class HarvestSleepTests(unittest.TestCase):
    def prepared(self):
        s = Session('steady')
        s.loop.sleep_learning = True
        s.learn()
        self.assertIsNone(s.loop.model)
        self.assertIsNone(s.loop.learning['admission'])
        self.assertGreaterEqual(len(s.loop.learning['records']), 5)
        for d in s.loop.decisions.values():
            d['day_cycle'] = dict(phase='exploration')
        s.loop._prospective = deepcopy(s.loop.learning), None
        return s.loop

    def step(self, a, slot, phase='night', status='waited', linked=True):
        p = deepcopy(next(reversed(a.observations.values())))
        p.update(observation_id='night:'+str(slot), capture_us=slot*250000,
                 pose_ref='night-pose', body_revision=0)
        d = dict(day_cycle=dict(phase=phase), action=['wait', 0])
        review(a, p, d)
        a.observations[p['observation_id']] = p
        a.decisions[p['observation_id']] = d
        a.commands[p['observation_id']] = dict(kind='wait')
        a.results['op:'+p['observation_id']] = dict(status=status,
            after_pose_ref='night-pose' if linked else 'wrong', after_revision=0,
            executed_us=p['capture_us'])
        return d

    def test_daytime_deferred_night_real_t1_once(self):
        a = self.prepared()
        raw = deepcopy(a.learning['records'])
        for slot in range(224, 228):
            self.step(a, slot)
            self.assertIsNone(a._prospective[1])
        d = self.step(a, 228)
        learning, model = a._prospective
        self.assertEqual(d['sleep_learning']['result'], 'ADOPTED')
        self.assertIsNotNone(model)
        self.assertEqual(learning['records'], raw)
        self.assertEqual(learning['admission']['candidate']['support_count'], 3)
        self.assertEqual(learning['admission']['candidate']['validation_count'], 2)
        self.assertEqual(len(learning['admission']['canonical']['model_cutover']['records']), 1)
        frozen = deepcopy(learning['sleep']['cycle'])
        self.step(a, 229)
        self.assertEqual(a._prospective[0]['sleep']['cycle'], frozen)

    def test_safety_and_bad_body_receipt_interrupt_rest(self):
        for bad in ('safety', 'unlinked', 'failed'):
            a = self.prepared()
            for slot in range(224, 227):
                self.step(a, slot)
            self.step(a, 227, phase='safety' if bad == 'safety' else 'night',
                      linked=bad != 'unlinked', status='stale' if bad == 'failed' else 'waited')
            self.step(a, 228)
            self.assertIsNone(a._prospective[1])
            self.assertEqual(a._prospective[0]['sleep']['cycle']['rest_us'], 0)

    def test_insufficient_and_counterexample_do_not_adopt(self):
        for count, expected in ((2, 'INSUFFICIENT_EVIDENCE'), (5, 'REJECT')):
            a = self.prepared()
            a._prospective[0]['records'] = a._prospective[0]['records'][:count]
            a._prospective[0]['records'][0]['acquired'] = False
            for slot in range(224, 229):
                d = self.step(a, slot)
            self.assertEqual(d['sleep_learning']['result'], expected)
            self.assertIsNone(a._prospective[1])

    def test_day_rollover_does_not_complete_short_sleep(self):
        a = self.prepared()
        self.step(a, 254)
        self.step(a, 255)
        self.step(a, 256, phase='orientation')
        self.assertIsNone(a._prospective[1])
        self.assertEqual(a._prospective[0]['sleep']['completed'][0]['status'], 'interrupted')

    def test_world_observe_replay_and_agent_isolation(self):
        w = World('sleep-world')
        campaign = HarvestCampaign(w.run_id, 2, mb_field_mode='enabled', harvest_state=True)
        for aid, a in campaign.agents.items():
            a.sleep_learning = True
            campaign.configure(dict(w.context(aid), schema=campaign.schema, clock_id='world-sim-v1',
                selection_profile='steady', mb_field_mode='enabled', teaching=dict(statement_id='t',
                source='god_statue', sample_observation='s', appearance='brown_capped_ovoid',
                predicate='food_after_known_processing')))
        for slot in range(224, 230):
            p = w.packet('npc_a', slot)
            c = campaign.observe(p)['command']
            before = deepcopy(campaign.agents['npc_a'].learning)
            self.assertEqual(campaign.observe(p)['command'], c)
            self.assertEqual(campaign.agents['npc_a'].learning, before)
            campaign.result(w.execute(c, p))
        a = campaign.agents['npc_a']
        self.assertEqual(a.learning['sleep']['cycle']['result']['status'], 'INSUFFICIENT_EVIDENCE')
        self.assertNotIn('sleep', campaign.agents['npc_b'].learning)

    def test_cross_action_review_keeps_differences_and_missing(self):
        a = self.prepared()
        # Explicit synthetic mixed experiences exercise the shared comparator;
        # not claimed as World evidence or support for the harvest model.
        for index, (oid, source) in enumerate(a.observations.items()):
            a.commands[oid]['kind'] = ('move', 'turn', 'pickup', 'wait')[index % 4]
            a.results['op:'+oid]['status'] = ('blocked', 'turned', 'not_found', 'waited')[index % 4]
            source['hazard'] = dict(coverage='complete', features=[])
        before = deepcopy((a.observations, a.learning))
        material = prepare(a, dict(capture_us=56000000))
        out = inspect(material)
        self.assertEqual(len(out['records']), 4)
        self.assertEqual(len(out['pair_results']), 6)
        self.assertEqual({r['action'] for r in out['records']}, {'move', 'turn', 'pickup', 'wait'})
        self.assertTrue(any(p['different_relations'] for p in out['pair_results']))
        self.assertEqual(out['candidate_admission'], 'none')
        self.assertEqual((a.observations, a.learning), before)
        material['records'][0]['food_coverage'] = 'partial'
        unknown = inspect(material)
        self.assertTrue(any(any(m['kind'] == 'context' for m in p['coverage']['missing'])
                            for p in unknown['pair_results']))

    def test_sleep_sources_freeze_before_later_changes(self):
        a = self.prepared()
        self.step(a, 224)
        frozen = deepcopy(a._prospective[0]['sleep']['cycle']['records'])
        a._prospective[0]['records'] = []
        for slot in range(225, 229):
            self.step(a, slot)
        self.assertEqual(a._prospective[0]['sleep']['cycle']['records'], frozen)
        self.assertIsNotNone(a._prospective[1])

    def test_saved_world_night_adoption_and_mixed_reviews(self):
        import json
        from pathlib import Path
        reports = json.loads(Path('tests/fixtures/lightweight_sleep_comparison.json').read_text())
        self.assertEqual(reports['False']['pickups'], 48)
        self.assertEqual(reports['True']['pickups'], 48)
        for aid in ('npc_a', 'npc_c'):
            a = reports['True']['agents'][aid]
            first = a['sleep']['completed'][0]
            self.assertEqual(first['result']['status'], 'ADOPTED')
            self.assertEqual(first['completed_us'], 57250000)
            self.assertEqual(first['result']['model_ref'], a['model_ref'])
            self.assertGreater(len(first['relation_review']['pair_results']), 0)
            self.assertGreater(len({r['action'] for r in first['relation_review']['records']}), 1)
        b = reports['True']['agents']['npc_b']
        self.assertIsNone(b['model_ref'])
        self.assertEqual(b['sleep']['cycle']['result']['status'], 'INSUFFICIENT_EVIDENCE')


if __name__ == '__main__':
    unittest.main()
