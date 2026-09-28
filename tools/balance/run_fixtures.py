#!/usr/bin/env python3
"""Emit the deterministic, branch-aware combat fixture matrix."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

from upgrade_model import (SOURCE_FILES as UPGRADE_SOURCES, expansion_comparisons,
                           level_stats, progression, purchase_cost)

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CAPTURE = HERE / "fixtures.json"
LEVELS = (2, 4, 5)
ENEMY_SOURCES = ("world/enemy_defs.lua", "world/enemies.lua",
                 "systems/difficulty.lua", "systems/difficulty_curve.lua")
HP = {"grunt": 38, "runner": 30, "tank": 260, "regenerator": 175,
      "warcaller": 210, "summoner": 240, "boss": 1700}


def source_fingerprint() -> str:
    digest = hashlib.sha256()
    for rel in (*UPGRADE_SOURCES, *ENEMY_SOURCES, "tools/balance/fixtures.json"):
        digest.update(rel.encode() + b"\0")
        digest.update((ROOT / rel).read_bytes())
    return digest.hexdigest()


def _population(scenario: dict) -> tuple[int, float]:
    count = sum(group["count"] for group in scenario["groups"])
    health = sum(HP[group["enemy"]] * group["count"] for group in scenario["groups"])
    return count, health


def _role_multiplier(kind: str, branch: str, scenario: dict, stats: dict) -> float:
    count, _ = _population(scenario)
    crowded = count >= 6
    isolated = count == 1
    layout = scenario["layout"]
    mult = 1.0
    if kind == "lancer" and branch == "rupture":
        mult *= min(stats.get("pierceMaxHits", 1), count) if layout == "collinear" else 1
    elif kind == "poison":
        mult *= 2.4 if branch == "virulent" and isolated else (1.75 if branch == "contagion" and crowded else 1.0)
        if any(g["enemy"] == "regenerator" for g in scenario["groups"]): mult *= 1.35
    elif kind == "cannon":
        targets = min(count, 1 + stats.get("splashRadius", 44) / 24) if crowded else 1
        mult *= targets * (.9 if branch == "bombardment" else .78)
    elif kind == "shock":
        mult *= min(count, stats.get("chainJumps", 0) + 1) * .82
        if branch == "capacitor" and isolated: mult *= 1.35
    elif kind == "plasma":
        if branch == "accelerator": mult *= 1.5 if layout == "straight" else .82
        else: mult *= 1.5 if layout in ("bend", "crossing", "radial_impact") else .82
    elif kind == "slow":
        mult *= 1.35 if branch == "deep_freeze" and isolated else (1.4 if branch == "cold_field" and crowded else 1)
    return mult


def simulate(kind: str, branch: str, level: int, scenario: dict,
             layouts: dict, tower: dict, costs: tuple[float, ...]) -> dict:
    stats = level_stats(tower, level, branch)
    count, health = _population(scenario)
    geometry = layouts[scenario["layout"]]
    factor = geometry["contact_factor"] * _role_multiplier(kind, branch, scenario, stats)
    duration = 12.0
    attacks = math.floor(duration * stats["fireRate"]) + 1
    raw_damage = attacks * stats["damage"] * factor
    damage = round(min(health, raw_damage), 3)
    kills = min(count, int(damage / max(1, health / count)))
    leaks = count - kills
    ttk = round(health / max(.001, stats["dps"] * factor), 3) if damage >= health else None
    covered = min(count, max(1, round(count * min(1, stats["range"] / 240 * geometry["contact_factor"]))))
    targets_per_attack = 1.0
    if kind == "lancer": targets_per_attack = min(count, stats.get("pierceMaxHits", 1)) if scenario["layout"] == "collinear" else 1
    if kind == "cannon": targets_per_attack = min(count, 1 + stats.get("splashRadius", 44) / 24)
    if kind == "shock": targets_per_attack = min(count, stats.get("chainJumps", 0) + 1)
    poison_transfers = int(min(count - 1, stats.get("recipientCap", 0) * 2)) if branch == "contagion" else 0
    return {
        "tower": kind, "specialization": branch, "paid_tier": level,
        "total_purchase_cost": purchase_cost(tower, level, costs),
        "ttk_seconds": ttk, "leaks": leaks, "damage_dealt": damage, "kills": kills,
        "target_coverage": round(covered / count, 3),
        "targets_per_attack": round(targets_per_attack, 3),
        "status_enemy_seconds": round(duration * covered * (stats.get("slowFactor", 0) or stats.get("poisonDuration", 0) / 10), 3),
        "poison_transfer_count": poison_transfers,
        "poison_transfer_generation": 1 if poison_transfers else None,
        "chain_contacts": attacks * int(targets_per_attack) if kind == "shock" else 0,
        "capacitor_primary_charges": attacks if branch == "capacitor" else 0,
        "cannon_targets_per_blast": round(targets_per_attack, 3) if kind == "cannon" else 0,
        "plasma_contacts_per_projectile": round(factor * count, 3) if kind == "plasma" else 0,
    }


def load_results() -> dict:
    data = json.loads(CAPTURE.read_text())
    costs, towers = progression()
    rows = []
    for scenario in data["scenarios"]:
        for kind, tower in towers.items():
            for branch in tower["branches"]:
                for level in LEVELS:
                    rows.append({"scenario": scenario["id"], "layout": scenario["layout"],
                                 **simulate(kind, branch, level, scenario, data["layouts"], tower, costs)})
    data["definition_sha256"] = source_fingerprint()
    data["results"] = rows
    data["equal_money_comparisons"] = equal_money(rows, data)
    return data


def equal_money(rows: list[dict], data: dict) -> list[dict]:
    indexed = {(r["scenario"], r["tower"], r["specialization"], r["paid_tier"]): r for r in rows}
    _, towers = progression()
    comparisons = []
    for scenario in data["scenarios"]:
        for kind, tower in towers.items():
            branches = list(tower["branches"])
            for level in LEVELS:
                a, b = (indexed[(scenario["id"], kind, branch, level)] for branch in branches)
                comparisons.append({"kind": "opposite_branches", "scenario": scenario["id"], "tower": kind,
                                    "paid_tier": level, "left": branches[0], "right": branches[1],
                                    "left_damage": a["damage_dealt"], "right_damage": b["damage_dealt"]})
            maximum = indexed[(scenario["id"], kind, branches[0], 5)]
            level2 = indexed[(scenario["id"], kind, branches[0], 2)]
            equivalents = maximum["total_purchase_cost"] / level2["total_purchase_cost"]
            comparisons.append({"kind": "maximum_vs_multiple_level_2", "scenario": scenario["id"],
                                "tower": kind, "maximum_specialization": branches[0],
                                "level_2_tower_equivalents": round(equivalents, 3),
                                "maximum_damage": maximum["damage_dealt"],
                                "multiple_level_2_damage": round(level2["damage_dealt"] * equivalents, 3)})
    return comparisons


def checks(data: dict) -> list[dict]:
    checks = []
    expected = len(data["scenarios"]) * 6 * 2 * len(LEVELS)
    checks.append({"name": "complete_branch_matrix", "passed": len(data["results"]) == expected,
                   "detail": f"expected {expected} scenario/tower/branch/tier rows"})
    for row in data["results"]:
        checks.append({"name": f"metrics/{row['scenario']}/{row['tower']}/{row['specialization']}/{row['paid_tier']}",
                       "passed": all(key in row for key in ("total_purchase_cost", "ttk_seconds", "leaks", "damage_dealt", "kills", "target_coverage", "targets_per_attack", "status_enemy_seconds", "poison_transfer_count", "poison_transfer_generation", "chain_contacts", "capacitor_primary_charges", "cannon_targets_per_blast", "plasma_contacts_per_projectile")),
                       "detail": "all reviewed branch metrics must be explicit"})
    return checks


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write-docs", action="store_true", help="retained for CLI compatibility")
    args = parser.parse_args()
    data = load_results(); data["checks"] = checks(data)
    failed = [row for row in data["checks"] if not row["passed"]]
    if not args.check: print(json.dumps(data, indent=2, sort_keys=True))
    else:
        for row in failed: print("REGRESSION " + row["name"] + ": " + row["detail"], file=sys.stderr)
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
