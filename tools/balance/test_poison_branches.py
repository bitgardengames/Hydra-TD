import unittest
from pathlib import Path

from poison_branch_benchmark import CONTAGION, DENSE, ISOLATED, LEVELS, run, validate


ROOT = Path(__file__).resolve().parents[2]


class PoisonBranchBenchmarkTest(unittest.TestCase):
    def test_required_scenario_matrix_and_margins(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * (len(ISOLATED) + len(DENSE)))

    def test_runtime_tiers_and_recipient_caps_match(self):
        source = (ROOT / "world/tower_defs.lua").read_text()
        self.assertIn("virulent = {tiers", source)
        self.assertIn("contagion = {", source)
        for level, (_, _, _, radius, fraction, cap) in CONTAGION.items():
            needle = (f"spreadRadius = {radius}, transferFraction = {fraction:.2f}, "
                      f"recipientCap = {cap}")
            self.assertIn(needle, source, f"tier {level}")
        self.assertNotIn("loop = true", source)

    def test_transfer_is_one_generation_and_duration_capped(self):
        source = (ROOT / "world/enemies.lua").read_text()
        self.assertIn("e.poisonGeneration == 0", source)
        self.assertIn("other.poisonGeneration = 1", source)
        self.assertIn("min(source.poisonTimer or 0, 3)", source)
        self.assertNotIn("infect.loop", source)
        self.assertIn("e.poisonStacks <= 0", source)  # regeneration suppression


if __name__ == "__main__":
    unittest.main()
