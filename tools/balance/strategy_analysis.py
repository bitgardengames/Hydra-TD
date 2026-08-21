#!/usr/bin/env python3
"""Deterministic build-family diversity and perturbation audit.

This is a strategy-level static model, not a path simulator.  It deliberately
counts canonical role/branch/region/ability plans instead of purchase-order
permutations and tests every viable plan against the same small mistakes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import challenge_fixtures

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BANDS = HERE / "strategy_bands.json"
TOWERS = ("slow", "lancer", "poison", "cannon", "shock", "plasma")

# Different allocations express different role mixtures; labels are part of a
# family's identity while the generated counts prove that it is affordable.
MIXES = {
    "focused": {"lancer": 7, "cannon": 1, "slow": 1},
    "control": {"slow": 4, "lancer": 4, "plasma": 2},
    "attrition": {"poison": 4, "lancer": 3, "slow": 1},
    "splash": {"cannon": 4, "shock": 3, "lancer": 2},
    "chain": {"shock": 4, "lancer": 3, "cannon": 1},
    "lane": {"plasma": 4, "slow": 2, "lancer": 2},
}
REGIONS = {"choke": 11_500, "distributed": 10_700, "exit_guard": 10_250}
BRANCHES = {"output": 11_500, "coverage": 10_900}
ABILITIES = {"burst_control": 12_200, "formation_economy": 11_650}
PERTURBATIONS = ("move_tower", "delay_upgrade_or_ability", "substitute_tower", "income_loss")


def allocate(towers: dict, money: int, specialists: list[str], weights: dict) -> dict:
    """Reserve required counters, then use a weighted deterministic sampler."""
    counts = {kind: 1 for kind in specialists}
    spent = sum(towers[k]["cost"] for k in counts)
    # Preserve a small reserve so the income-loss test is not synonymous with
    # exact-spend failure. Different mixes still spend independently.
    limit = money * 97 // 100
    sequence = sorted(TOWERS, key=lambda k: (-weights.get(k, 0), k))
    cursor = 0
    while sequence and spent + min(towers[k]["cost"] for k in sequence) <= limit:
        eligible = [k for k in sequence if spent + towers[k]["cost"] <= limit]
        if not eligible:
            break
        # Smooth weighted round-robin prevents every family collapsing to its
        # first/cheapest tower while remaining stable across Python versions.
        expanded = [k for k in sequence for _ in range(max(1, weights.get(k, 0)))]
        kind = next((expanded[(cursor + n) % len(expanded)] for n in range(len(expanded))
                     if expanded[(cursor + n) % len(expanded)] in eligible), eligible[0])
        cursor = (cursor + 7) % len(expanded)
        counts[kind] = counts.get(kind, 0) + 1
        spent += towers[kind]["cost"]
    return counts


def raw_damage(towers: dict, counts: dict) -> int:
    return sum(towers[k]["sustained_damage"] * n for k, n in counts.items())


def analyze() -> dict:
    challenge = challenge_fixtures.build_report()
    towers, _, _, _, _ = challenge_fixtures.definitions()
    config = json.loads(BANDS.read_text())
    puzzles = set(config.get("puzzles", []))
    encounters = []
    for difficulty, maps in challenge["difficulties"].items():
        for map_id, waves in maps.items():
            for wave in waves:
                encounter_id = f"{difficulty}/{map_id}/wave_{wave['wave']}"
                candidates = []
                for mix, weights in MIXES.items():
                    counts = allocate(towers, wave["purchasing_power_before_wave"],
                                      wave["required_specialists"], weights)
                    spent = sum(towers[k]["cost"] * n for k, n in counts.items())
                    base = raw_damage(towers, counts)
                    for region, region_bp in REGIONS.items():
                        for branch, branch_bp in BRANCHES.items():
                            for ability, ability_bp in ABILITIES.items():
                                output = base * region_bp * branch_bp * ability_bp // 1_000_000_000_000
                                # Tactical effects can be reused throughout a five-second
                                # pressure window; cap at a broad 5.5x rather than claim an
                                # exact simulated DPS conversion.
                                output = output * 55 // 10
                                required = wave["required_damage"]
                                if output < required:
                                    continue
                                replacement = min(counts, key=lambda k: (towers[k]["sustained_damage"], k))
                                alternatives = [k for k in TOWERS if k != replacement and
                                                spent - towers[replacement]["cost"] + towers[k]["cost"] <= wave["purchasing_power_before_wave"]]
                                substituted = max((base - towers[replacement]["sustained_damage"] + towers[k]["sustained_damage"]
                                                   for k in alternatives), default=0)
                                perturbed = {
                                    "move_tower": output * 8800 // 10000,
                                    "delay_upgrade_or_ability": output * 8500 // 10000,
                                    "substitute_tower": substituted * region_bp * branch_bp * ability_bp * 55 // 10_000_000_000_000,
                                    "income_loss": output if spent <= wave["purchasing_power_before_wave"] * 95 // 100 else 0,
                                }
                                passes = sum(value >= required for value in perturbed.values())
                                candidates.append({"roles": mix, "towers": counts, "upgrade_branch": branch,
                                                   "placement_region": region, "ability_loadout": ability,
                                                   "cost": spent, "margin_bp": (output - required) * 10000 // max(1, required),
                                                   "perturbation_passes": [k for k, v in perturbed.items() if v >= required],
                                                   "perturbation_pass_bp": passes * 10000 // len(PERTURBATIONS)})
                # Canonical fields intentionally omit purchase order.
                unique = {(c["roles"], tuple(sorted(c["towers"].items())), c["upgrade_branch"],
                           c["placement_region"], c["ability_loadout"]): c for c in candidates}
                families = sorted(unique.values(), key=lambda c: (-c["perturbation_pass_bp"], -c["margin_bp"],
                                                                  c["roles"], c["placement_region"], c["upgrade_branch"], c["ability_loadout"]))
                robust = sum(c["perturbation_pass_bp"] >= 5000 for c in families)
                mean = sum(c["perturbation_pass_bp"] for c in families) // max(1, len(families))
                encounters.append({"id": encounter_id, "puzzle": encounter_id in puzzles,
                                   "viable_family_count": len(families), "robust_family_count": robust,
                                   "mean_perturbation_pass_bp": mean,
                                   "worst_family_margin_bp": min((c["margin_bp"] for c in families), default=-10000),
                                   "families": families})
    source_hash = hashlib.sha256((BANDS.read_bytes() +
        (ROOT / "world/tower_defs.lua").read_bytes() +
        (ROOT / "systems/ability_defs.lua").read_bytes() +
        (ROOT / "systems/campaign_wave_defs.lua").read_bytes())).hexdigest()
    return {"format_version": 1, "definition_sha256": source_hash,
            "perturbations": list(PERTURBATIONS), "bands": config,
            "encounters": encounters}


def failures(report: dict) -> list[str]:
    bands = report["bands"]["defaults"]
    failed = []
    for row in report["encounters"]:
        if row["puzzle"]:
            continue
        checks = (("viable families", row["viable_family_count"], bands["minimum_viable_families"]),
                  ("robust families", row["robust_family_count"], bands["minimum_robust_families"]),
                  ("mean perturbation", row["mean_perturbation_pass_bp"], bands["minimum_mean_perturbation_pass_bp"]),
                  ("worst margin", row["worst_family_margin_bp"], bands["minimum_worst_family_margin_bp"]))
        for label, actual, minimum in checks:
            if actual < minimum:
                failed.append(f"{row['id']}: {label} {actual} below {minimum}")
    return failed


def summary(report: dict) -> dict:
    rows = report["encounters"]
    return {"encounters": len(rows), "minimum_viable_families": min(r["viable_family_count"] for r in rows),
            "minimum_robust_families": min(r["robust_family_count"] for r in rows),
            "mean_viable_families": sum(r["viable_family_count"] for r in rows) // len(rows),
            "mean_perturbation_pass_bp": sum(r["mean_perturbation_pass_bp"] for r in rows) // len(rows),
            "puzzles": sum(r["puzzle"] for r in rows)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    report = analyze()
    failed = failures(report)
    if args.check:
        for item in failed:
            print("STRATEGY REGRESSION " + item, file=sys.stderr)
    elif args.summary:
        print(json.dumps(summary(report), sort_keys=True))
    else:
        report["failures"] = failed
        report["summary"] = summary(report)
        print(json.dumps(report, indent=2, sort_keys=True))
    return bool(failed)


if __name__ == "__main__":
    raise SystemExit(main())
