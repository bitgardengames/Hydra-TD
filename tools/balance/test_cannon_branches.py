import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cannon_branch_benchmark import (IMPACT_DISTANCES, LEVELS, SCENARIOS,
                                     damage, run, validate)


ROOT = Path(__file__).resolve().parents[2]


class CannonBranchBenchmarkTest(unittest.TestCase):
    def test_runtime_definition_uses_one_tier_scaled_blast(self):
        source = (ROOT / "world/tower_defs.lua").read_text()
        cannon = source[source.index("\tcannon = {"):source.index("\n\tshock = {")]
        self.assertIn("siege = {", cannon)
        self.assertIn("bombardment = {", cannon)
        self.assertEqual(cannon.count('{id = "move_to_target_point"}'), 3)
        self.assertEqual(cannon.count('{id = "aoe_damage"'), 3)
        self.assertNotIn('{id = "hit_damage"}', cannon)
        for level in (2, 3, 4, 5):
            self.assertIn(f"[{level}] = {{", cannon)
        modules = (ROOT / "systems/modules.lua").read_text()
        self.assertIn("if splashRadius then data.radius = splashRadius", modules)
        self.assertIn("if splashFalloff then data.falloff = splashFalloff", modules)

    def test_projectile_speed_is_part_of_splash_lead_prediction(self):
        towers = (ROOT / "world/towers.lua").read_text()
        self.assertIn("t.projSpeed = tier.projSpeed or def.projSpeed", towers)
        self.assertIn("(t.def.projSpeed or t.projSpeed) / max(1, t.projSpeed or 1)",
                      towers)

    def test_required_scenario_and_impact_matrix(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * len(SCENARIOS))
        self.assertEqual(IMPACT_DISTANCES, (0, 30, 44, 56, 70, 84))

    def test_acceptance_margins(self):
        for row in run():
            with self.subTest(level=row.level, scenario=row.scenario):
                if row.scenario.startswith("isolated:"):
                    self.assertGreaterEqual(row.siege_damage,
                                            row.bombardment_damage * 1.30)
        for level in LEVELS:
            self.assertGreater(damage(level, "bombardment", (56, 70, 84)),
                               damage(level, "siege", (56, 70, 84)))
            layout = SCENARIOS["group:normal_grunts"]
            self.assertGreater(damage(level, "bombardment", layout),
                               damage(level, "siege", layout))


if __name__ == "__main__":
    unittest.main()
