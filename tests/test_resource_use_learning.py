import copy
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from runtime.resource_use_learning import (ResourceUseLearning, SCHEMA, ADAPTER, inspect_experiences,
                                           RELATION, boundary)
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar
from test_boundary_defense import config as l11_config, request as l11_request


def setup():
    c = l11_config()
    c = {k: v for k, v in c.items() if k not in ('reaction', 'relation', 'site_relation')}
    c['schema'] = SCHEMA
    canonical = GameAIFrozenComparisonSidecar()
    loop = ResourceUseLearning(c['run_id'], canonical); loop.configure(c)
    return loop, c, canonical


def use(c, i):
    r = l11_request(c, i, i*4000000)
    r.update(episode_id=f'episode-{i}', scheduled_us=i*4000000)
    for side in ('before','after'):
        for v in r['record'][side]['visible']:
            v['distance'] = 1; v['relative_position']['x'] = 1
    return r


def outcome(c, i, acquired=True, partial=False):
    peer = use(c, i); n = peer['record']['notice']; capture = n['capture_us'] + 2000000
    r = dict(episode_id=peer['episode_id'], notice_id=n['notice_id'], operation_id=f'own-{i}', event_id=f'own-event-{i}',
             capture_us=capture, now_us=capture, attempted=True, acquired=acquired, coverage='partial' if partial else 'complete')
    for side in ('before','after'):
        p = copy.deepcopy(peer['record'][side]); p.update(packet_id=f'own-{side}-{i}', capture_us=capture)
        if not acquired: p['visible'] = [v for v in p['visible'] if v['kind'] != 'food']
        r[side] = p
    r['effect'] = {k:r[k] for k in ('event_id','operation_id','notice_id','capture_us','attempted','acquired')}
    r['effect'].update(source=ADAPTER, observer=c['defender'], hand_before=0, hand_after=int(acquired))
    return r


def materials(loop, c, negative=False, contradict=False, partial=False):
    for i in range(1,7):
        loop.observe(use(c,i)); loop.record(outcome(c,i,not negative and not (contradict and i==6),partial and i==6))
    loop.review(dict(episode_id='episode-1',reviewer='explicit-harness',basis='independent count residual review',evidence='test-review'))
    return dict(learning_id='learning',formation_episodes=[f'episode-{i}' for i in (1,2,3)],
                validation_episodes=[f'episode-{i}' for i in (4,5,6)],activate=True)


def current(loop,c,req):
    learned=loop.learn(req); loop.begin(dict(operation_id='reaction',learning_id=req['learning_id']))
    return learned,loop.observe(use(c,7))['receipt']


class ResourceUseTests(unittest.TestCase):
    def test_six_scenarios(self):
        for negative,activate,contra,partial,disp,status,threshold in (
            (False,True,False,False,'RETAIN','known',11),
            (False,False,False,False,'RETAIN','unknown',3),
            (True,True,False,False,'RETAIN','known',3),
            (True,False,False,False,'RETAIN','unknown',3),
            (False,True,True,False,'REJECT','unknown',3),
            (False,True,False,True,'DEFER','unknown',3)):
            with self.subTest(negative=negative,activate=activate,contra=contra,partial=partial):
                loop,c,can=setup(); req=materials(loop,c,negative,contra,partial);req['activate']=activate
                result,receipt=current(loop,c,req)
                self.assertEqual(result['inspection']['disposition'],disp)
                self.assertEqual(receipt['prediction']['status'],status)
                self.assertEqual(receipt['evaluation']['warning_threshold'],threshold*1000000)
                self.assertEqual(receipt['permit'] is not None,threshold==3)
                self.assertEqual(result['inspection']['formation_support'],3)
                self.assertEqual(result['inspection']['validation_count'],None if partial else 3)
                own=loop.record(outcome(c,7))['receipt']
                if status=='known': self.assertEqual(own['comparison']['E']['deltas'],{'own_food_acquired':float(negative)})
                else: self.assertIsNone(own['comparison']['E'])
                self.assertEqual(own['F_prime']['model_ref'],receipt['prediction']['model_ref'])
                self.assertEqual(can.snapshot()['T1_materials']['count'],1)
                self.assertEqual(can.snapshot()['T1_selection']['count'],1)
                self.assertEqual(can.snapshot()['T1_reconstruction']['count'],int(disp=='RETAIN'))

    def test_exact_inputs_differ_only_at_activation(self):
        runs=[]
        for activate in (False,True):
            loop,c,can=setup();req=materials(loop,c);req['activate']=activate
            learned,r=current(loop,c,req);runs.append((loop.snapshot(),r))
        for i in range(1,7): self.assertEqual(runs[0][0]['episodes'][f'episode-{i}'],runs[1][0]['episodes'][f'episode-{i}'])
        self.assertEqual(runs[0][1]['section'],runs[1][1]['section'])
        self.assertIsNotNone(runs[0][1]['permit']);self.assertIsNone(runs[1][1]['permit'])

    def test_mixed_formation_and_missing_comparison_are_distinct(self):
        loop,c,_=setup();req=materials(loop,c)
        es=[loop.snapshot()['episodes'][f'episode-{i}']['own']['receipt']['experience'] for i in range(1,7)]
        es[0]['acquired']=False
        self.assertEqual(inspect_experiences(es[:3],es[3:])['formation_status'],'no_candidate')
        es[0]['section']['reasons']=['not_attempted']
        self.assertEqual(inspect_experiences(es[:3],es[3:])['formation_status'],'formation_unavailable')

    def test_counterexample_and_unavailable_defer_preserves_counterexample(self):
        loop,c,_=setup();materials(loop,c,contradict=True)
        es=[loop.snapshot()['episodes'][f'episode-{i}']['own']['receipt']['experience'] for i in range(1,7)]
        es[3]['section']['boundary']['site_ref']='other'
        r=inspect_experiences(es[:3],es[3:]);self.assertEqual(r['disposition'],'DEFER')
        self.assertIsNone(r['validation_count']);self.assertFalse(r['validation_results'][2]['agrees'])

    def test_replay_after_expiry_concurrent_and_no_extra_support(self):
        loop,c,_=setup();r=use(c,1)
        with ThreadPoolExecutor(4) as pool: outputs=list(pool.map(loop.observe,[r]*8))
        self.assertEqual(sum(x['new_event'] for x in outputs),1)
        own=outcome(c,1);loop.record(own)
        self.assertFalse(loop.observe(dict(r,now_us=999999999))['new_event'])
        self.assertFalse(loop.record(dict(own,now_us=999999999))['new_result'])
        self.assertEqual(len(loop.snapshot()['episodes']),1)

    def test_alias_scope_hidden_fields_and_atomic_rejection(self):
        loop,c,can=setup();loop.observe(use(c,1));loop.record(outcome(c,1))
        for edit in ('event','packet','scope','hidden','boolean'):
            r=use(c,2)
            if edit=='event': r['record']['notice']['event_id']='event-1';r['record']['effect']['event_id']='event-1'
            if edit=='packet': r['record']['notice']['before_id']='own-before-1';r['record']['before']['packet_id']='own-before-1'
            if edit=='scope':r['record']['notice']['actor']='foreign'
            if edit=='hidden':r['return_schedule']=True
            if edit=='boolean':r['record']['notice']['seq']=True
            before=(loop.snapshot(),can.snapshot())
            with self.assertRaises(ValueError):loop.observe(r)
            self.assertEqual((loop.snapshot(),can.snapshot()),before)
        loop.observe(use(c,2));own=outcome(c,2);own['event_id']='own-event-1';own['effect']['event_id']=own['event_id']
        with self.assertRaisesRegex(ValueError,'alias'):loop.record(own)

    def test_malformed_own_proof_does_not_create_experience(self):
        for kind in ('hand','food','radius','event'):
            loop,c,can=setup();loop.observe(use(c,1));r=outcome(c,1)
            if kind=='hand':r['effect']['hand_after']=0
            if kind=='food':r['before']['visible']=r['after']['visible']
            if kind=='radius':
                r['before']['visible'][1]['distance']=2;r['before']['visible'][1]['relative_position']['x']=2
            if kind=='event':r['effect']['event_id']='wrong'
            before=(loop.snapshot(),can.snapshot())
            with self.assertRaises(ValueError):loop.record(r)
            self.assertEqual((loop.snapshot(),can.snapshot()),before)

    def test_unattempted_and_partial_are_not_negative_votes(self):
        for attempted in (True,False):
            loop,c,_=setup();loop.observe(use(c,1));r=outcome(c,1,False,attempted)
            if not attempted:
                r.update(attempted=False,acquired=None);r['effect'].update(attempted=False,acquired=None)
            result=loop.record(r)['receipt'];self.assertIsNone(result['experience']['acquired'])
            self.assertEqual(result['F_prime']['status'],'unavailable')

    def test_deadlines_and_capacity(self):
        loop,c,_=setup()
        for i in range(1,9):loop.observe(use(c,i));loop.record(outcome(c,i))
        with self.assertRaisesRegex(ValueError,'capacity'):loop.observe(use(c,9))
        self.assertFalse(loop.observe(use(c,1))['new_event'])
        for field in ('now_us','scheduled_us'):
            loop,c,_=setup();r=use(c,1);r[field]+=1000000
            with self.assertRaises(ValueError):loop.observe(r)
        loop,c,_=setup();loop.observe(use(c,1));r=outcome(c,1);r['now_us']+=1000001
        with self.assertRaisesRegex(ValueError,'expired'):loop.record(r)

    def test_training_never_warns_or_adds_load(self):
        loop,c,_=setup();materials(loop,c)
        self.assertEqual(loop.snapshot()['load'],0)
        self.assertTrue(all(e['receipt']['status']=='training_disabled' and not e['receipt']['permit'] for e in loop.snapshot()['episodes'].values()))

    def test_review_is_required_and_bound_to_actual_count_sources(self):
        loop,c,can=setup();loop.observe(use(c,1));loop.record(outcome(c,1))
        self.assertEqual(can.snapshot()['M_delta']['active_count'],0)
        loop.review(dict(episode_id='episode-1',reviewer='operator',basis='purpose-bound residual',evidence='source'))
        self.assertEqual(can.snapshot()['M_delta']['active_count'],1)

    def test_t1_partial_failure_resumes_same_series_before_and_after_commit(self):
        for method in ('expand_t1_materials','inspect_t1_materials','reconstruct_t1','cutover_reentry'):
            for after in (False,True):
                with self.subTest(method=method,after=after):
                    loop,c,can=setup();req=materials(loop,c);parent=can.model_for_agent(c['defender']).model_ref
                    original=getattr(can,method)
                    def fail(*a,**kw):
                        if after:original(*a,**kw)
                        raise ValueError('injected failure')
                    with patch.object(can,method,side_effect=fail):
                        with self.assertRaisesRegex(ValueError,'injected'):loop.learn(req)
                    with self.assertRaisesRegex(ValueError,'incomplete'):loop.begin(dict(operation_id='begin',learning_id='learning'))
                    if method!='cutover_reentry' or not after:self.assertEqual(can.model_for_agent(c['defender']).model_ref,parent)
                    done=loop.learn(req);self.assertEqual(done['phase'],'complete')
                    before=(loop.snapshot(),can.snapshot());self.assertEqual(loop.learn(req),done)
                    self.assertEqual((loop.snapshot(),can.snapshot()),before)
                    snap=can.snapshot()
                    for key in ('T1_materials','T1_selection','T1_reconstruction','model_cutover'):self.assertEqual(snap[key]['count'],1)

    def test_no_retained_relation_still_records_complete_t1_b(self):
        loop,c,can=setup();learned=loop.learn(materials(loop,c,contradict=True))
        self.assertEqual(learned['selection']['counts'],{'RETAIN':1,'REJECT':1,'DEFER':9})
        self.assertIsNone(learned['artifact']);self.assertEqual(can.snapshot()['M_delta']['active_count'],1)

    def test_learning_conflict_distinct_sources_and_freeze(self):
        loop,c,_=setup();req=materials(loop,c)
        bad=copy.deepcopy(req);bad['validation_episodes'][0]='episode-1'
        with self.assertRaisesRegex(ValueError,'alias'):loop.learn(bad)
        loop.learn(req)
        with self.assertRaisesRegex(ValueError,'conflict'):loop.learn(dict(req,activate=False))
        with self.assertRaisesRegex(ValueError,'frozen'):loop.observe(use(c,7))

    def test_active_model_interpretation_without_local_experience(self):
        loop,c,can=setup();req=materials(loop,c);current(loop,c,req)
        section=loop.snapshot()['episodes']['episode-7']['receipt']['section']
        model=can.model_for_agent(c['defender'])
        self.assertEqual(model.interpret_resource_use(section)['values'],{'own_food_acquired':1.})
        section['boundary']['site_ref']='unlearned-site'
        self.assertEqual(model.interpret_resource_use(section)['status'],'unavailable')

    def test_conflicting_adopted_relations_and_incomplete_inputs_unavailable(self):
        loop,c,can=setup();current(loop,c,materials(loop,c));section=loop.snapshot()['episodes']['episode-7']['receipt']['section']
        model=can.model_for_agent(c['defender']);relation=copy.deepcopy(model.adopted_relations[0]);relation['relation']['predicts_acquired']=False
        conflict=replace(model,adopted_relations=model.adopted_relations+(relation,))
        self.assertEqual(conflict.interpret_resource_use(section)['reasons'],['conflicting_relations'])
        section['reasons']=['partial'];self.assertEqual(model.interpret_resource_use(section)['status'],'unavailable')

    def test_pending_outcome_keeps_frozen_decision_model(self):
        loop,c,can=setup();req=materials(loop,c);req['activate']=False;learned,r=current(loop,c,req)
        can.cutover_reentry(artifact_id=learned['artifact']['artifact_id'],expected_active_model_ref=learned['artifact']['parent_model_ref'],operator='test',basis='late activation',evidence='test')
        result=loop.record(outcome(c,7))['receipt']
        self.assertEqual(result['F_prime']['model_ref'],r['prediction']['model_ref']);self.assertIsNone(result['comparison']['E'])

    def test_warning_result_binding_and_single_reaction_budget(self):
        loop,c,_=setup();req=materials(loop,c);req['activate']=False;_,r=current(loop,c,req);p=r['permit']
        result=dict(permit=p,status='displayed',started_us=p['capture_us']+100000,ended_us=p['capture_us']+360000,readback='WARNING',cleared='')
        self.assertTrue(loop.result(result)['new_result']);self.assertFalse(loop.result(result)['new_result'])
        with self.assertRaisesRegex(ValueError,'capacity'):loop.observe(use(c,8))
        bad=copy.deepcopy(result);bad['permit']['actor']='other'
        with self.assertRaises(ValueError):loop.result(bad)

    def test_snapshot_and_outputs_detached(self):
        loop,c,_=setup();req=materials(loop,c);done,r=current(loop,c,req)
        done['inspection']['candidate']['support_count']=99;r['evaluation']['load_after']=99
        self.assertEqual(loop.snapshot()['load'],4000000)
        self.assertEqual(loop.learn(req)['inspection']['candidate']['support_count'],3)

    def test_entirely_missing_sources_stay_unavailable(self):
        loop,c,_=setup();r=use(c,1)
        r['record'].update(before=None,after=None,effect=None)
        receipt=loop.observe(r)['receipt']
        self.assertEqual(receipt['prediction']['status'],'unavailable')
        self.assertIsNone(receipt['prediction']['values'])
        own=loop.record(outcome(c,1))['receipt']
        self.assertIsNone(own['experience']['acquired'])
        self.assertIsNone(own['comparison']['E'])

    def test_unavailable_current_notice_never_uses_baseline_quiet(self):
        loop,c,_=setup();req=materials(loop,c);loop.learn(req);loop.begin(dict(operation_id='begin',learning_id='learning'))
        r=use(c,7);r['record']['notice']['coverage']='partial'
        receipt=loop.observe(r)['receipt']
        self.assertEqual(receipt['status'],'unavailable')
        self.assertIsNone(receipt['evaluation']);self.assertIsNone(receipt['permit'])
        self.assertEqual(loop.snapshot()['load'],0)

    def test_event_alias_across_peer_and_own_roles_rejected(self):
        loop,c,_=setup();loop.observe(use(c,1));loop.record(outcome(c,1))
        r=use(c,2);r['record']['notice']['event_id']='own-event-1';r['record']['effect']['event_id']='own-event-1'
        with self.assertRaisesRegex(ValueError,'alias'):loop.observe(r)

    def test_http_opt_in_scope_and_isolation(self):
        from http.server import ThreadingHTTPServer
        from threading import Thread
        from urllib.request import Request,urlopen
        from urllib.error import HTTPError
        import runtime.bridge as bridge
        for flags in ({'host':'0.0.0.0'},{'boundary_defense':True},{'sensory_observation':True},{'luanti_learning_loop':True}):
            with self.assertRaises(ValueError):bridge.run(resource_use_learning=True,**flags)
        loop,c,can=setup()
        server=ThreadingHTTPServer(('127.0.0.1',0),bridge.BridgeHandler)
        thread=Thread(target=server.serve_forever,daemon=True);thread.start()
        url=f'http://127.0.0.1:{server.server_port}'
        def post(path,data):
            with urlopen(Request(url+path,data=json.dumps(data).encode(),headers={'Content-Type':'application/json'})) as response:return json.load(response)
        try:
            with self.assertRaises(HTTPError) as exc:post('/v1/resource-use/observe',use(c,1))
            self.assertEqual(exc.exception.code,404);exc.exception.close()
            server.resource_use=loop
            with patch.object(bridge,'CANONICAL_SIDECAR',can):
                self.assertTrue(post('/v1/resource-use/observe',use(c,1))['new_event'])
                before=loop.snapshot()
                with self.assertRaises(HTTPError) as exc:post('/v1/resource-use/observe',{})
                self.assertEqual(exc.exception.code,422);exc.exception.close()
                self.assertEqual(loop.snapshot(),before)
                with urlopen(url+'/v1/resource-use-snapshot') as response:self.assertEqual(json.load(response)['learning'],before)
        finally:server.shutdown();thread.join();server.server_close()

    def test_begin_rejects_model_changed_outside_declared_learning(self):
        loop,c,can=setup();req=materials(loop,c);req['activate']=False;learned=loop.learn(req)
        can.cutover_reentry(artifact_id=learned['artifact']['artifact_id'],expected_active_model_ref=learned['artifact']['parent_model_ref'],operator='other',basis='external switch',evidence='external')
        with self.assertRaisesRegex(ValueError,'model_changed'):loop.begin(dict(operation_id='begin',learning_id='learning'))
        self.assertIsNone(loop.snapshot()['reaction'])

    def test_section_preserves_actual_time_pose_coverage_and_source(self):
        loop,c,_=setup();r=use(c,1)
        r['now_us']+=23456
        for item in r['record'].values():item['capture_us']+=12345
        receipt=loop.observe(r)['receipt'];section=receipt['section'];n=r['record']['notice']
        self.assertEqual(section['capture_us'],n['capture_us'])
        self.assertEqual(section['pose_ref'],n['pose_ref'])
        self.assertEqual(section['source_ids']['before'],n['before_id'])
        self.assertEqual(section['dimensions'],['own_food_acquired'])
        self.assertEqual(section['coverage'],{'receipt':'complete','before':'complete','after':'complete'})

    def test_real_replay(self):
        path=Path(__file__).parent/'fixtures/luanti_l12_replay.json'
        from integrations.luanti.tests.check_resource_use_learning import check
        for data in json.loads(path.read_text(encoding='utf-8'))['runs']:check(data)


if __name__=='__main__':unittest.main()
