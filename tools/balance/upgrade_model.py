"""Parse the shipped branch-aware tower progression model.

The public helpers in this module are shared by all balance simulations.  In
particular, callers must select a specialization for paid tiers; silently
interpolating one tier-five ``dmgMult`` curve used to erase most of the authored
branch behaviour.
"""
from __future__ import annotations

import hashlib
import re
from functools import cache
from pathlib import Path

from lua_source import named_entries, numeric_field, table_body

ROOT = Path(__file__).resolve().parents[2]
TOWERS = ("slow", "lancer", "poison", "cannon", "shock", "plasma")
SOURCE_FILES = ("world/tower_defs.lua", "world/towers.lua",
                "systems/branch_tier_resolver.lua", "world/projectiles.lua",
                "world/projectile_behaviors.lua")


def source_fingerprint() -> str:
    digest = hashlib.sha256()
    for rel in SOURCE_FILES:
        digest.update(rel.encode() + b"\0")
        digest.update((ROOT / rel).read_bytes())
    return digest.hexdigest()


def _fields(body: str, context: str) -> dict[str, float]:
    """Return numeric scalar fields, including values expressed in tiles."""
    result = {}
    for key, value in re.findall(r"\b(\w+)\s*=\s*([0-9.]+)(?:\s*\*\s*Constants\.TILE)?", body):
        result[key] = float(value)
        if re.search(rf"\b{re.escape(key)}\s*=\s*{re.escape(value)}\s*\*\s*Constants\.TILE", body):
            result[key] *= 48
    return result


@cache
def progression() -> tuple[tuple[float, ...], dict[str, dict]]:
    runtime_path = ROOT / "world/towers.lua"
    runtime = runtime_path.read_text()
    raw_costs = table_body(runtime, "UPGRADE_COST_MULTIPLIERS", runtime_path)
    costs = tuple(float(value) for value in re.findall(r"[0-9.]+", raw_costs))
    if len(costs) != 4 or costs[0] <= 1 or any(a >= b for a, b in zip(costs, costs[1:])):
        raise ValueError("expected four increasing paid-tier cost multipliers")

    path = ROOT / "world/tower_defs.lua"
    definitions = path.read_text()
    root = table_body(definitions, "return", path)
    towers = {}
    for kind, raw in named_entries(root, "return", path).items():
        if kind not in TOWERS:
            continue
        upgrade = table_body(raw, "upgrade", path)
        branches_body = table_body(upgrade, "branches", path)
        branches = {}
        for branch, branch_body in named_entries(branches_body, "branches", path).items():
            tiers_body = table_body(branch_body, "tiers", path)
            tiers = {}
            for level in range(2, 6):
                match = re.search(rf"\[{level}\]\s*=\s*\{{([^{{}}]*)\}}", tiers_body)
                if not match:
                    raise ValueError(f"missing {kind}/{branch} paid tier {level}")
                tiers[level] = _fields(match.group(1), f"{kind}/{branch}/{level}")
            branches[branch] = {"tiers": tiers}
        if len(branches) != 2:
            raise ValueError(f"{kind} must define exactly two branches")
        towers[kind] = {
            "cost": numeric_field(raw, "cost", path, kind),
            "damage": numeric_field(raw, "damage", path, kind),
            "fireRate": numeric_field(raw, "fireRate", path, kind),
            "range": numeric_field(raw, "range", path, kind),
            "branches": branches,
        }
    branch_ids = [branch for tower in towers.values() for branch in tower["branches"]]
    if len(branch_ids) != len(set(branch_ids)):
        raise ValueError("branch identifiers must be globally unique and stable")
    return costs, towers


def level_stats(tower: dict, level: int, branch: str | None = None) -> dict[str, float]:
    """Resolve an explicit authored tier; level one is the unbranched base."""
    if level not in range(1, 6):
        raise ValueError("tower level must be 1..5")
    stats = {"damage": tower["damage"], "fireRate": tower["fireRate"],
             "range": tower["range"]}
    if level == 1:
        stats["dps"] = stats["damage"] * stats["fireRate"]
        return stats
    # Compatibility for presentation-only callers: this still resolves an
    # authored branch tier (never an interpolated aggregate curve). Simulators
    # pass their specialization explicitly.
    if not branch:
        branch = next(iter(tower["branches"]))
    try:
        tier = tower["branches"][branch]["tiers"][level]
    except KeyError as exc:
        raise ValueError(f"unknown specialization {branch!r} at level {level}") from exc
    stats.update(tier)
    stats["damage"] = tower["damage"] * tier.get("dmgMult", 1)
    stats["fireRate"] = tower["fireRate"] * tier.get("fireMult", 1)
    stats["range"] = tower["range"] + tier.get("rangeAdd", 0)
    stats["dps"] = stats["damage"] * stats["fireRate"]
    return stats


def purchase_cost(tower: dict, level: int, costs: tuple[float, ...]) -> int:
    return round(tower["cost"] * (1 + sum(costs[:level - 1])))


def expansion_comparisons() -> list[dict]:
    costs, towers = progression()
    rows = []
    for kind, tower in towers.items():
        base = level_stats(tower, 1)
        for branch in tower["branches"]:
            for tier in range(2, 6):
                current = level_stats(tower, tier, branch)
                previous = level_stats(tower, tier - 1, branch) if tier > 2 else base
                marginal = current["dps"] - previous["dps"]
                raw = marginal / (base["dps"] * costs[tier - 2])
                constrained = raw * (current["range"] / previous["range"]) / (.72 * .88) * (1 + .08*(tier-2))
                rows.append({"tower": kind, "specialization": branch, "tier": tier,
                             "upgrade_cost": round(tower["cost"] * costs[tier - 2]),
                             "total_purchase_cost": purchase_cost(tower, tier, costs),
                             "base_tower_equivalents": costs[tier - 2],
                             "open_placement_output_ratio": round(raw, 3),
                             "constrained_utility_ratio": round(constrained, 3),
                             "range_tiles": round(current["range"] / 48, 3)})
    return rows
