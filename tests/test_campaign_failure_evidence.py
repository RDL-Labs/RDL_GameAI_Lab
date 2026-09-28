"""A failed World must be saved before its success assertion rejects the run."""
import json
import lzma
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock,patch
from integrations.luanti.tests import run_return_campaign as runner
from integrations.luanti.tests.analyze_model_field import analyze


class FailureEvidenceTests(TestCase):
    def test_world_failure_preserves_live_runtime_and_returns_failure(self):
        with TemporaryDirectory() as folder:
            root=Path(folder);output=root/"output";artifact=root/"failed.json.xz"
            files=["runtime/current_harvest_state.py","integrations/luanti/scripts/test-learned-exploration-day.ps1",
                "runtime/landmark_return_campaign.py","runtime/landmark_day_cycle.py","runtime/exploration.py",
                "runtime/model_movement_field.py","runtime/terrain_resource_exploration.py","runtime/terrain_steering.py",
                "integrations/luanti/game/rdl_game/mods/rdl_bridge/multi_resource_fixture.lua"]
            for name in files:
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text("fixture")
            run="l15campaign-"+"0"*12
            world=dict(run_id=run,failure="HTTP failed",finished_us=123,agents={},stock_events=[],return_campaign=dict(events=[]))
            p=root/"integrations/luanti/worlds"/run/"l14b-evidence.json"
            p.parent.mkdir(parents=True);p.write_text(json.dumps(world))
            loop=MagicMock();loop.snapshot.return_value={"live_state":"retained"}
            with (
                patch.object(runner,"ROOT",root),
                patch.object(runner,"OUTPUT",output),
                patch.object(runner,"uuid4",return_value=SimpleNamespace(hex="0"*32)),
                patch.object(runner,"ReturnCampaign",return_value=loop),
                patch.object(runner,"ThreadingHTTPServer"),
                patch.object(runner,"Thread"),
                patch.object(runner.subprocess,"check_output",return_value="baseline"),
                patch.object(runner.subprocess,"run",return_value=SimpleNamespace(returncode=0)),
                patch.object(runner,"check") as check,
                patch("sys.argv",["runner","--output",str(artifact),"--periods","30","--model-field","disabled"]),
            ):
                with self.assertRaisesRegex(RuntimeError,"partial World/Runtime preserved"):runner.main()
                check.assert_not_called()
            with lzma.open(artifact,"rt") as stream:report=json.load(stream)
            self.assertEqual(report["runs"][0]["data"]["runtime"]["exploration"],{"live_state":"retained"})
            self.assertEqual(report["runs"][0]["data"]["world"],world)
            self.assertFalse(report["runs"][0]["summary"]["strict_acceptance"])
            summary=analyze(report)[0]
            self.assertEqual(summary["status"],"aborted")
            self.assertFalse(summary["acceptance"])

    def test_missing_runtime_is_not_reported_as_zero_model_effect(self):
        report=dict(predeclared=dict(model_field_mode="disabled"),runs=[dict(data=dict(runtime=None,
            world=dict(run_id="failed",failure="HTTP failed",agents={},stock_events=[],return_campaign=dict(events=[]))))])
        result=analyze(report)[0]
        self.assertEqual(result["state_basis"],"World only; Runtime metrics not inferred")
        self.assertNotIn("applied",result)
        self.assertFalse(result["acceptance"])
