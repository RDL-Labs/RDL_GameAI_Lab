from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
LUANTI = ROOT / "integrations" / "luanti"


class LuantiMultiAgentAssetTests(unittest.TestCase):
    def test_installer_packages_multi_agent_module(self):
        installer = (LUANTI / "scripts" / "install-game.ps1").read_text(encoding="utf-8")
        self.assertIn("multi_agent_food.lua", installer)
        self.assertIn("sensor_profiles.lua", installer)
        self.assertIn("distant_observation.lua", installer)
        self.assertIn("audition_observation.lua", installer)
        self.assertIn("audition_receive_window.lua", installer)
        self.assertIn("life_sensory.lua", installer)
        self.assertIn("distant_sensor.lua", installer)
        self.assertIn("audition_window_sensor.lua", installer)
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "multi_agent_food.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "sensor_profiles.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "distant_observation.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "audition_observation.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "audition_receive_window.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "life_sensory.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "distant_sensor.lua").is_file())
        self.assertTrue((LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                         "audition_window_sensor.lua").is_file())

    def test_obs6_fixture_combines_life_and_isolated_sensor_frames(self):
        source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "multi_agent_food.lua").read_text(encoding="utf-8")
        sensory = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                   "life_sensory.lua").read_text(encoding="utf-8")
        script = (LUANTI / "scripts" / "test-observation-integration.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("sensory:attach(packet", source)
        self.assertIn("record_action_sound", source)
        self.assertIn('frame(agent_id, "vision_local"', sensory)
        self.assertIn('"vision_distant"', sensory)
        self.assertIn('"audition"', sensory)
        self.assertIn('dofile(modpath .. "/distant_sensor.lua")', sensory)
        self.assertIn('dofile(modpath .. "/audition_window_sensor.lua")', sensory)
        self.assertNotIn('color_band = agent_id ==', sensory)
        self.assertNotIn('self.time_us - window_us, self.time_us', sensory)
        self.assertIn("--sensory-observation", (LUANTI / "scripts" /
                      "test-multi-agent.ps1").read_text(encoding="utf-8"))
        self.assertIn("OBS6 LIFE PASS", script)

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
        self.assertIn("config.sensor_profile.vision_local.radius", source)
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

    def test_local_vision_uses_validated_agent_profile(self):
        profile_source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                          "sensor_profiles.lua").read_text(encoding="utf-8")
        fixture_source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                          "multi_agent_food.lua").read_text(encoding="utf-8")
        self.assertIn('radius = 12', profile_source)
        self.assertIn('radius = 8', profile_source)
        self.assertIn('error("unknown RDL sensor profile', profile_source)
        self.assertIn("config.sensor_profile.vision_local.radius", fixture_source)
        invalid_config = (LUANTI / "config" / "luanti-invalid-sensor-profile.conf").read_text(
            encoding="utf-8"
        )
        invalid_script = (LUANTI / "scripts" / "test-invalid-sensor-profile.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("rdl_sensor_profile_npc_a = unknown-profile", invalid_config)
        self.assertIn("unknown RDL sensor profile for npc_a: unknown-profile", invalid_script)

    def test_distant_fixture_has_finite_geometry_and_evidence_harness(self):
        source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "distant_observation.lua").read_text(encoding="utf-8")
        shared = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "distant_sensor.lua").read_text(encoding="utf-8")
        script = (LUANTI / "scripts" / "test-distant-observation.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("range_min_exclusive", shared)
        self.assertIn("horizontal_fov_deg", shared)
        self.assertIn("core.get_node_or_nil", shared)
        self.assertIn("#features < 4", shared)
        self.assertIn('dofile(core.get_modpath("rdl_bridge") .. "/distant_sensor.lua")', source)
        self.assertIn("occluded_hidden=true", script)
        self.assertIn('"world_position"', script)

    def test_audition_fixture_mixes_before_threshold_without_source_leaks(self):
        source = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "audition_receive_window.lua").read_text(encoding="utf-8")
        script = (LUANTI / "scripts" / "test-audition-observation.ps1").read_text(
            encoding="utf-8"
        )
        self.assertIn("direct_band_energy_v0", source)
        self.assertIn("emit_world_sound", source)
        self.assertIn("close_window", source)
        self.assertIn('dofile(core.get_modpath("rdl_bridge") ..', source)
        self.assertIn('"/audition_window_sensor.lua")', source)
        shared = (LUANTI / "game" / "rdl_game" / "mods" / "rdl_bridge" /
                  "audition_window_sensor.lua").read_text(encoding="utf-8")
        self.assertIn("count >= self.buffer_limit", shared)
        self.assertIn("agent.closed[start]", shared)
        self.assertIn("qualifying > self.detection_limit", shared)
        self.assertIn("agent.pose_revision", source)
        self.assertIn("factor = factor * 0.5", source)
        self.assertIn("cross_window_split=true", script)
        self.assertIn("duplicate_close_idempotent=true", script)
        self.assertIn('"source_id"', script)


if __name__ == "__main__":
    unittest.main()
