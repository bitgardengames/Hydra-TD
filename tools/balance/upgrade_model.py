"""Parse the shipped, stat-only tower progression model.

Canonical balance and replay fixtures import this module rather than copying
upgrade prices.
"""
from __future__ import annotations

import re
from pathlib import Path

from lua_source import numeric_field, table_body

ROOT = Path(__file__).resolve().parents[2]
TOWERS = ("slow", "lancer", "poison", "cannon", "shock", "plasma")


def progression() -> tuple[tuple[float, ...], dict[str, dict[str, float]]]:
    runtime = (ROOT / "world/towers.lua").read_text()
    raw_costs = table_body(runtime, "UPGRADE_COST_MULTIPLIERS", ROOT / "world/towers.lua")
    costs = tuple(float(value) for value in re.findall(r"[0-9.]+", raw_costs))
    if len(costs) != 4:
        raise ValueError("expected four runtime upgrade cost multipliers")
    if costs[0] <= 1 or any(current <= previous for previous, current in zip(costs, costs[1:])):
        raise ValueError("upgrade costs must exceed the base tower cost and increase each tier")

    definitions = (ROOT / "world/tower_defs.lua").read_text()
    towers = {}
    for kind in TOWERS:
        raw = table_body(definitions, kind, ROOT / "world/tower_defs.lua")
        upgrade = table_body(raw, "upgrade", ROOT / "world/tower_defs.lua")
        number = lambda body, key, default=None: numeric_field(
            body, key, ROOT / "world/tower_defs.lua", kind, default)
        towers[kind] = {
            "cost": number(raw, "cost"), "damage": number(raw, "damage"),
            "fireRate": number(raw, "fireRate"), "range": number(raw, "range"),
            "dmgMult": number(upgrade, "dmgMult", 1),
            "fireMult": number(upgrade, "fireMult", 1),
            "rangeAdd": number(upgrade, "rangeAdd", 0),
        }
    return costs, towers


def level_stats(tower: dict[str, float], level: int) -> dict[str, float]:
    """Mirror recomputeTowerStats: multipliers are max-level, range is per tier."""
    progress = (level - 1) / 4
    damage = tower["damage"] * (1 + (tower["dmgMult"] - 1) * progress)
    rate = tower["fireRate"] * (1 + (tower["fireMult"] - 1) * progress)
    return {"damage": damage, "fireRate": rate, "dps": damage * rate,
            "range": tower["range"] + tower["rangeAdd"] * (level - 1)}


def expansion_comparisons() -> list[dict]:
    """Compare every tier with equal-money base-tower expansion.

    Open placement uses raw output. Constrained placement credits the upgraded
    tower for retaining the best tile, continuous focus, less overkill, and its
    role; the bounded factors are explicit fixture assumptions, not runtime
    inputs.
    """
    costs, towers = progression()
    role_factor = {"slow": 1.28, "lancer": 1.05, "poison": 1.18,
                   "cannon": 1.16, "shock": 1.15, "plasma": 1.12}
    rows = []
    for kind, tower in towers.items():
        base = level_stats(tower, 1)
        previous = base
        for tier, multiplier in enumerate(costs, 2):
            current = level_stats(tower, tier)
            marginal = current["dps"] - previous["dps"]
            expansion = base["dps"] * multiplier
            raw = marginal / expansion
            range_gain = current["range"] / previous["range"]
            # A second tower averages 72% useful uptime after legal-tile/coverage
            # loss and 88% after target switching/overkill. Scarcity rises by tier.
            constrained = raw * role_factor[kind] * range_gain / (.72 * .88) * (1 + .08*(tier-2))
            rows.append({"tower": kind, "tier": tier,
                         "upgrade_cost": round(tower["cost"] * multiplier),
                         "base_tower_equivalents": multiplier,
                         "open_placement_output_ratio": round(raw, 3),
                         "constrained_utility_ratio": round(constrained, 3),
                         "range_tiles": round(current["range"], 3)})
            previous = current
    return rows
