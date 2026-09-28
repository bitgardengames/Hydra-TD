import unittest

from shock_branch_benchmark import LEVELS, capacitor_result, run, validate


class ShockBranchBenchmarkTest(unittest.TestCase):
    def test_required_scenario_matrix_and_margins(self):
        rows = run()
        validate(rows)
        self.assertEqual(len(rows), len(LEVELS) * 6)

    def test_charge_is_independent_of_chain_contacts(self):
        for level in LEVELS:
            with self.subTest(level=level):
                self.assertEqual(capacitor_result(level, 1)[1],
                                 capacitor_result(level, 8)[1])


if __name__ == "__main__":
    unittest.main()
