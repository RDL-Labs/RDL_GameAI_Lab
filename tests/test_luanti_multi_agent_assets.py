from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
LUANTI = ROOT / "integrations" / "luanti"


class LuantiMultiAgentAssetTests(unittest.TestCase):
    def test_installer_packages_multi_agent_module(self):
        installer = (LUANTI / "scripts" / "install-game.ps1").read_text(encoding="utf-8")
        self.assertIn("multi_agent_food.lua", installer)
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "multi_agent_food.lua").is_file())

    def test_fixture_has_explicit_mode_and_two_agent_evidence(self):
        config = (LUANTI / "config" / "luanti-multi-agent.conf").read_text(encoding="utf-8")
        script = (LUANTI / "scripts" / "test-multi-agent.ps1").read_text(encoding="utf-8")
        self.assertIn("rdl_fixture_mode = multi_agent_food", config)
        self.assertIn("pickup agent=npc_a target=food_a", script)
        self.assertIn("pickup agent=npc_b target=food_b", script)
        self.assertIn("latest_sections.npc_a", script)
        self.assertIn("latest_sections.npc_b", script)


if __name__ == "__main__":
    unittest.main()
