import unittest
from unittest.mock import patch
from integrations.luanti.tests.campaign_diagnostics import TimedLoop
import test_six_agent_campaign


class CampaignDiagnosticsTests(unittest.TestCase):
    def test_real_loop_response_and_state_unchanged(self):
        fixture=test_six_agent_campaign.SixAgentCampaignTests()
        a,sa=fixture.sessions();b,sb=fixture.sessions()
        measured=TimedLoop(b)
        packet=sa[0].packet()
        self.assertEqual(a.observe(packet),measured.observe(packet))
        self.assertEqual(a.snapshot(),b.snapshot())
        self.assertEqual(measured.diagnostics()["stats"]["1:observe"]["count"],1)

    def test_failure_preserved_and_slow_log_bounded(self):
        class Loop:
            def observe(self,p): raise ValueError("original failure")
        measured=TimedLoop(Loop())
        with patch("integrations.luanti.tests.campaign_diagnostics.perf_counter_ns",side_effect=[v for i in range(150) for v in (i*200000000,(i*200000000)+150000000)]):
            for i in range(150):
                with self.assertRaisesRegex(ValueError,"original failure"):
                    measured.observe(dict(capture_us=999999999999,agent_id="a"))
        result=measured.diagnostics()
        self.assertEqual(len(result["slow"]),128)
        self.assertEqual(result["stats"]["32:observe"]["count"],150)
        result["stats"].clear()
        self.assertTrue(measured.diagnostics()["stats"])

    def test_saved_luanti_smoke_has_bounded_separate_diagnostics(self):
        from pathlib import Path
        from integrations.luanti.tests.analyze_campaign_timing import analyze
        path=Path(__file__).parent/"fixtures"/"luanti_l15a_campaign_timing_smoke.json.xz"
        result=analyze(path)
        self.assertIsNone(result["failure"])
        self.assertGreater(result["export_us"],0)
        self.assertEqual(len(result["agents"]),6)
        self.assertTrue(all(a["runtime_observations"]==256 for a in result["agents"].values()))
        self.assertTrue(all(not v for a in result["accepted_without_received_reply"].values() for v in a.values()))
