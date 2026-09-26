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
        self.assertIn("deposit agent=npc_a base=base_a accepted=true", script)
        self.assertIn("deposit agent=npc_b base=base_b accepted=true", script)
        self.assertIn('"--base-food-life"', script)
        self.assertIn("/v1/life-snapshot", script)
        self.assertIn("latest_sections.npc_a", script)
        self.assertIn("latest_sections.npc_b", script)
        self.assertIn("radius_counts=A:$aVisible,B:$bVisible", script)

    def test_packet_admission_checks_observer_relative_radius(self):
        source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "multi_agent_food.lua").read_text(encoding="utf-8")
        self.assertIn("local observation_radius = 12", source)
        self.assertGreaterEqual(source.count("if distance <= observation_radius then"), 2)
        self.assertIn('id = "boundary_agent"', source)
        self.assertIn('id = "outside_agent"', source)

    def test_fixture_keeps_food_life_state_per_agent(self):
        source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "multi_agent_food.lua").read_text(encoding="utf-8")
        self.assertIn('base_id = "base_a"', source)
        self.assertIn('base_id = "base_b"', source)
        self.assertIn("config.base_food_stock", source)
        self.assertIn("config.result_accepted", source)
        self.assertIn("life_result_url", source)


if __name__ == "__main__":
    unittest.main()
