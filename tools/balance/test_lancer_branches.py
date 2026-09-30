import unittest
from pathlib import Path

from lancer_branch_benchmark import LEVELS, run, sustained_damage, validate


class LancerBranchBenchmarkTest(unittest.TestCase):
    def test_runtime_definition_matches_benchmark_contract(self):
        # Keep the executable report tied to the shipped Lua data rather than
        # allowing a later balance edit to silently stale the acceptance test.
        source = (Path(__file__).resolve().parents[2] / "world/tower_defs.lua").read_text()
        for level, (damage, rate) in {
            2: (1.55, 1.00),
            4: (2.75, 1.04),
            5: (3.50, 1.06),
        }.items():
            self.assertIn(f"[{level}] = {{dmgMult = {damage:.2f}, fireMult = {rate:.2f}", source)
        for level, (damage, rate, hits) in {
            2: (1.30, 1.045, 2),
            4: (2.15, 1.135, 3),
            5: (2.65, 1.18, 4),
        }.items():
            self.assertIn(f"[{level}] = {{dmgMult = {damage:.2f}, fireMult = {rate}", source)
            self.assertIn(f"pierceMaxHits = {hits}}}", source)
        profile = source[
            source.index("rupture = {") : source.index(
                "\n\t\t\t},\n\t\t},", source.index("rupture = {")
            )
        ]
        for behavior in (
            "move_linear",
            "hit_circle",
            "hit_damage",
            "pierce",
            "lancer_hit_fx",
            "draw_lancer",
        ):
            self.assertIn(f'id = "{behavior}"', profile)
        for excluded in ("lancer_rail_momentum", "bleed", "ricochet", "move_homing"):
            self.assertNotIn(excluded, profile)

    def test_required_scenario_matrix_and_thresholds(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * 10)

    def test_rupture_three_target_margin(self):
        for level in LEVELS:
            with self.subTest(level=level):
                ratio = sustained_damage(level, "rupture", 3) / sustained_damage(level, "marksman")
                self.assertGreaterEqual(ratio, 1.35)


if __name__ == "__main__":
    unittest.main()
