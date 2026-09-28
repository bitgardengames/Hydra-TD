import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from slow_branch_benchmark import LEVELS, PATHS, run, validate


ROOT = Path(__file__).resolve().parents[2]


class SlowBranchBenchmarkTest(unittest.TestCase):
    def test_runtime_definition_matches_benchmark_contract(self):
        source = (ROOT / "world/tower_defs.lua").read_text()
        self.assertIn("deep_freeze = {", source)
        self.assertIn("cold_field = {", source)
        self.assertIn('{id = "apply_slow", data = {factor = 0.58, dur = 1.7}}', source)
        self.assertIn(
            '{id = "slow_field", data = {radius = 62, life = 2.4, factor = 0.36, tick = 0.25, dur = 0.4}}',
            source,
        )
        for level in LEVELS:
            self.assertIn(f"[{level}] = {{", source)
        status = (ROOT / "world/projectile_behaviors/status_proc.lua").read_text()
        self.assertIn('emitEvent(p, "spawn_slow_field")', status)
        self.assertIn('p.hitOrigin ~= "slow_field"', status)
        self.assertIn("radiusVisitContext.factor = 1 - min", status)
        self.assertNotIn("slowFactor *", status)

    def test_required_scenario_and_geometry_matrix(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * len(PATHS) * 4)
        self.assertEqual(
            {scenario for _, _, scenario, _, _ in rows},
            {"runner", "runner_pack", "warcaller", "warcaller_group"},
        )

    def test_acceptance_margins(self):
        rows = run()
        for level, fixture, scenario, deep, field in rows:
            with self.subTest(level=level, fixture=fixture, scenario=scenario):
                if scenario == "runner":
                    self.assertGreaterEqual(deep, field * 1.20)
                elif scenario in ("runner_pack", "warcaller_group"):
                    self.assertGreaterEqual(field, deep * 1.30)


if __name__ == "__main__":
    unittest.main()
