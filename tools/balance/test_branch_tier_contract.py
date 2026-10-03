"""Focused source-level guards for the shared specialization contract.

The deterministic combat benchmarks cover numeric outcomes; these checks keep
the runtime wiring that makes opposing variants safe in the same simulation.
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "balance"))
from upgrade_model import progression


class BranchTierContractTest(unittest.TestCase):
    def test_every_tower_has_two_complete_stable_branches(self):
        _, towers = progression()
        self.assertEqual(len(towers), 6)
        ids = []
        for kind, tower in towers.items():
            with self.subTest(tower=kind):
                self.assertEqual(len(tower["branches"]), 2)
                for branch, definition in tower["branches"].items():
                    ids.append(branch)
                    self.assertEqual(set(definition["tiers"]), {2, 3, 4, 5})
        self.assertEqual(len(ids), len(set(ids)))

    def test_one_resolver_owns_variant_mechanics(self):
        resolver = (ROOT / "systems/branch_tier_resolver.lua").read_text()
        modules = (ROOT / "systems/modules.lua").read_text()
        towers = (ROOT / "world/towers.lua").read_text()
        emissions = (ROOT / "world/emissions.lua").read_text()
        self.assertIn("BranchTierResolver.resolve(t", towers)
        self.assertIn("BranchTierResolver.resolve(tower)", modules)
        self.assertIn("Modules.getFireProfile(t)", emissions)
        for mechanic in (
            "slowFactor",
            "poisonOrigin",
            "infect_spread",
            "capacitor",
            "splashFalloff",
            "tickRate",
        ):
            with self.subTest(mechanic=mechanic):
                corpus = (
                    resolver
                    + (ROOT / "world/projectile_behaviors/status_proc.lua").read_text()
                    + (ROOT / "world/projectiles.lua").read_text()
                )
                self.assertIn(mechanic, corpus)

    def test_preview_clone_carries_choice_without_touching_live_tower(self):
        source = (ROOT / "world/towers.lua").read_text()
        clone = source[
            source.index("local function cloneForPreview") : source.index(
                "local function behaviorMap"
            )
        ]
        self.assertIn("clone.specialization =", clone)
        self.assertIn("clone._cache = {}", clone)
        self.assertNotIn("t.specialization = specialization", clone)

    def test_cancel_and_wrong_branch_are_free(self):
        towers = (ROOT / "world/towers.lua").read_text()
        validation = towers.index('return false, "specialization_required"')
        locked = towers.index('return false, "specialization_locked"')
        charge = towers.index("State.money = State.money - cost")
        self.assertLess(validation, charge)
        self.assertLess(locked, charge)
        picker = (ROOT / "ui/module_picker.lua").read_text()
        close = picker[
            picker.index("function ModulePicker.close") : picker.index(
                "function ModulePicker.isActive"
            )
        ]
        self.assertNotIn("money", close.lower())

    def test_specialization_is_chosen_when_buying_level_three(self):
        towers = (ROOT / "world/towers.lua").read_text()
        picker = (ROOT / "ui/module_picker.lua").read_text()
        inspect = (ROOT / "ui/bottom_bar_inspect.lua").read_text()
        resolver = (ROOT / "systems/branch_tier_resolver.lua").read_text()

        self.assertIn("if currentLevel == 2 then", towers)
        self.assertIn("if currentLevel == 2 then\n\t\tt.specialization = specialization", towers)
        self.assertIn("(tower.level or 1) == 2", picker)
        self.assertIn("(tower.level or 1) ~= 2", picker)
        self.assertIn('t.level == 2 and "actions.specialize"', inspect)
        self.assertIn("if level > 2 then", resolver)
        self.assertIn("level == 2 and def.upgrade.tiers[2]", resolver)

    def test_sell_refund_uses_selected_difficulty_for_every_purchase(self):
        towers = (ROOT / "world/towers.lua").read_text()
        difficulty = (ROOT / "systems/difficulty.lua").read_text()
        self.assertIn("floor(def.cost * diff.sellRefund)", towers)
        self.assertIn("floor(cost * diff.sellRefund)", towers)
        for name in ("easy", "normal", "hard"):
            self.assertIn(f"\t{name} = {{", difficulty)

    def test_modules_are_exclusive_to_explicit_playtest_mode(self):
        modes = (ROOT / "systems/run_modes.lua").read_text()
        self.assertIn("RunModes.MODULE_PLAYTEST", modes)
        self.assertIn("RunModes.get(state) == RunModes.MODULE_PLAYTEST", modes)


if __name__ == "__main__":
    unittest.main()
