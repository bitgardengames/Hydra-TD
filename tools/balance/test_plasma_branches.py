import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from plasma_branch_benchmark import FIXTURES, LEVELS, run, validate

ROOT = Path(__file__).resolve().parents[2]


class PlasmaBranchBenchmarkTest(unittest.TestCase):
    def test_runtime_profiles_stay_linear_and_tick_based(self):
        source = (ROOT / "world/tower_defs.lua").read_text()
        plasma = source[source.index("\tplasma = {"):]
        self.assertIn("accelerator = {", plasma)
        self.assertIn("overcharged = {", plasma)
        self.assertEqual(plasma.count('{id = "move_linear"'), 3)
        self.assertEqual(plasma.count('{id = "tick_damage"'), 3)
        for forbidden in ("move_homing", "move_spiral", "move_boomerang",
                          "aoe_damage", "move_to_target_point"):
            self.assertNotIn(forbidden, plasma)

    def test_selected_tier_scales_projectile_geometry(self):
        modules = (ROOT / "systems/modules.lua").read_text()
        self.assertIn("if travelDistance then data.dist = travelDistance end", modules)
        self.assertIn("if tickRadius then data.radius = tickRadius end", modules)
        self.assertIn("if tickRate then data.rate = tickRate end", modules)
        towers = (ROOT / "world/towers.lua").read_text()
        self.assertIn("t.projSpeed = tier.projSpeed or def.projSpeed", towers)
        damage_source = (ROOT / "world/projectile_behaviors/damage.lua").read_text()
        self.assertIn("p.visualScale = radius / 16", damage_source)

    def test_geometry_matrix_and_acceptance_margins(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * len(FIXTURES))
        self.assertEqual({f.name for f in FIXTURES}, {
            "straight_lane", "ninety_degree_bend", "crossing", "loop"})
        for row in rows:
            with self.subTest(level=row["level"], geometry=row["geometry"]):
                self.assertGreater(float(row["accelerator_lower_count"]), 1)
                self.assertGreater(float(row["overcharged_lower_count"]), 1)


if __name__ == "__main__":
    unittest.main()
