#!/usr/bin/env python3
"""Deterministic campaign challenge/economy audit from the shipped Lua data.

The report deliberately uses only integers.  Source decimals are converted to
basis points, multiplied as integers, and rounded half-up once when an enemy is
spawned (durability) or killed (income).  This keeps the fixture useful on
machines without Lua and avoids Python's banker rounding.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BP = 10_000
WINDOW_MS = 5_000
# Mechanic pressure is intentionally broad, rather than pretending that path
# geometry or a particular loadout can be solved statically.
MECHANIC_BP = {"fast": 10_500, "armored": 12_500, "regenerates": 12_000,
               "shielded": 11_500, "support": 11_500, "summons": 12_000}
COUNTERS = {"fast": "slow", "armored": "cannon", "regenerates": "poison",
            "shielded": "shock", "support": "lancer", "summons": "cannon"}
# Curriculum-phase envelopes, expressed as required/affordable DPS basis points.
# Introduction waves (2 and 4) allow the intended specialist spike; practice and
# exam waves tighten as the player's accumulated income smooths composition.
RATIO_BANDS = [(3_000, 18_000), (4_000, 35_000), (4_000, 16_000),
               (3_000, 35_000), (2_500, 22_000), (2_500, 20_000),
               (2_500, 14_000), (2_500, 12_000), (2_500, 11_000),
               (3_000, 10_000)]


def half_up(numerator: int, denominator: int) -> int:
    return (numerator + denominator // 2) // denominator


def decimal_bp(value: str) -> int:
    whole, _, fraction = value.partition(".")
    return int(whole) * BP + int((fraction + "0000")[:4])


def block(text: str, declaration: str) -> str:
    match = re.search(declaration + r"\s*(?:=\s*)?\{", text)
    if not match:
        raise ValueError(f"missing Lua table {declaration!r}")
    depth = 1
    for pos in range(match.end(), len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return text[match.end():pos]
    raise ValueError(f"unterminated Lua table {declaration!r}")


def named_blocks(text: str) -> dict[str, str]:
    result = {}
    for match in re.finditer(r"^\s*([a-z][a-z0-9_]*)\s*=\s*\{", text, re.M):
        depth = 1
        for pos in range(match.end(), len(text)):
            depth += (text[pos] == "{") - (text[pos] == "}")
            if depth == 0:
                result[match.group(1)] = text[match.end():pos]
                break
    return result


def number(body: str, key: str, default: str | None = None) -> str:
    found = re.search(rf"\b{key}\s*=\s*([0-9.]+)", body)
    if found:
        return found.group(1)
    if default is not None:
        return default
    raise ValueError(f"missing field {key!r}")


def definitions():
    towers_text = (ROOT / "world/tower_defs.lua").read_text()
    enemies_text = (ROOT / "world/enemy_defs.lua").read_text()
    waves_text = (ROOT / "systems/campaign_wave_defs.lua").read_text()
    difficulty_text = (ROOT / "systems/difficulty.lua").read_text()
    curve_text = (ROOT / "systems/difficulty_curve.lua").read_text()

    towers = {}
    for kind, body in named_blocks(block(towers_text, r"return")).items():
        if not re.search(r"\bcost\s*=", body):
            continue
        cost = int(float(number(body, "cost")))
        damage = decimal_bp(number(body, "damage"))
        rate = decimal_bp(number(body, "fireRate"))
        dps = half_up(damage * rate, BP * BP)
        poison = re.search(r"apply_poison.*?dps\s*=\s*([0-9.]+)", body, re.S)
        tick = re.search(r"tick_damage.*?rate\s*=\s*([0-9.]+)", body, re.S)
        if poison:
            dps += half_up(decimal_bp(poison.group(1)), BP)
        if tick:
            dps = half_up(damage * BP, decimal_bp(tick.group(1)) * BP)
        towers[kind] = {"cost": cost, "sustained_damage": max(1, dps)}

    enemies = {}
    for kind, body in named_blocks(block(enemies_text, r"return")).items():
        if not re.search(r"\bhp\s*=", body) or not re.search(r"\breward\s*=", body):
            continue
        traits_match = re.search(r"traits\s*=\s*\{([^}]*)", body)
        traits = re.findall(r'"([a-z_]+)"', traits_match.group(1)) if traits_match else []
        shield = re.search(r"shield\s*=\s*\{([^}]*)", body)
        enemies[kind] = {"hp_bp": decimal_bp(number(body, "hp")),
                         "reward": decimal_bp(number(body, "reward")),
                         "shield_bp": decimal_bp(number(shield.group(1), "hp")) if shield else 0,
                         "traits": traits, "boss": "boss = true" in body}

    diff_root = block(difficulty_text, r"Difficulty\.defs")
    diffs = {name: {"hp_bp": decimal_bp(number(body, "enemyHpBias")),
                    "boss_bp": decimal_bp(number(body, "bossHpBias")),
                    "reward_bp": decimal_bp(number(body, "rewardBias")),
                    "money": int(float(number(body, "startMoney")))}
             for name, body in named_blocks(diff_root).items()}
    curve = {key: decimal_bp(number(curve_text, key)) for key in
             ("localStartHp", "localEndHp", "localExponent", "finalMapHp")}

    maps = {}
    wave_root = block(waves_text, r"local wavesByMapId")
    group_re = re.compile(r'g\("([a-z_]+)",\s*(\d+),\s*([0-9.]+),\s*([0-9.]+)\)')
    for map_id, body in named_blocks(wave_root).items():
        maps[map_id] = []
        for wave in range(1, 11):
            row = re.search(rf"\[{wave}\]\s*=\s*\{{([^\n]+)", body)
            if not row:
                raise ValueError(f"missing {map_id} wave {wave}")
            maps[map_id].append([{"kind": k, "count": int(c),
                                  "spacing_ms": half_up(decimal_bp(s) * 1000, BP),
                                  "delay_ms": half_up(decimal_bp(d) * 1000, BP)}
                                 for k, c, s, d in group_re.findall(row.group(1))])
    return towers, enemies, diffs, curve, maps


def curve_multiplier_bp(curve: dict, wave: int, map_index: int, diff: dict, boss: bool) -> int:
    # Evaluate authored fractional exponent once, then immediately quantize the
    # multiplier. All enemy arithmetic after this boundary is fixed point.
    progress = (wave - 1) / 9
    local = curve["localStartHp"] / BP + (curve["localEndHp"] - curve["localStartHp"]) / BP * \
        progress ** (curve["localExponent"] / BP)
    map_mult = 1 + (curve["finalMapHp"] / BP - 1) * (map_index - 1) / 14
    value = int(local * map_mult * diff["hp_bp"] + 0.5)
    if boss:
        value = half_up(value * diff["boss_bp"] * 9, BP * 10)
    return value


def build_report() -> dict:
    towers, enemies, diffs, curve, maps = definitions()
    best = max(towers.values(), key=lambda tower: tower["sustained_damage"] / tower["cost"])
    report = {"format_version": 2, "units": {"durability": "threat points",
              "damage": "damage points per second", "money": "dollars",
              "multipliers_and_ratios": "basis points"}, "engagement_window_seconds": 5,
              "ratio_bands_bp": [list(x) for x in RATIO_BANDS], "difficulties": {}}
    for diff_name, diff in diffs.items():
        diff_maps = {}
        for map_index, (map_id, waves) in enumerate(maps.items(), 1):
            money, rows = diff["money"], []
            for wave_no, groups in enumerate(waves, 1):
                spawns, time = [], 0
                income = durability = enemy_count = 0
                composition = {}
                mechanics = set()
                for group in groups:
                    time += group["delay_ms"]
                    for index in range(group["count"]):
                        kind = group["kind"]
                        # Generic campaign bosses use an archetype at runtime. A
                        # generic boss is the stable conservative fixture proxy.
                        enemy = enemies[kind]
                        enemy_count += 1
                        composition[kind] = composition.get(kind, 0) + 1
                        mult = curve_multiplier_bp(curve, wave_no, map_index, diff, enemy["boss"])
                        raw = half_up((enemy["hp_bp"] + enemy["shield_bp"]) * mult, BP * BP)
                        mechanic_bp = max((MECHANIC_BP.get(t, BP) for t in enemy["traits"]), default=BP)
                        threat = half_up(raw * mechanic_bp, BP)
                        spawn = time + index * group["spacing_ms"]
                        spawns.append((spawn, threat))
                        durability += threat
                        income += half_up(enemy["reward"] * diff["reward_bp"], BP * BP)
                        mechanics.update(t for t in enemy["traits"] if t in COUNTERS)
                    time = spawns[-1][0]
                spawns.sort()
                peak = left = running = 0
                for right, (at, threat) in enumerate(spawns):
                    running += threat
                    while spawns[left][0] < at - WINDOW_MS:
                        running -= spawns[left][1]
                        left += 1
                    peak = max(peak, running)
                affordable = money // best["cost"] * best["sustained_damage"]
                required = half_up(peak, 5)
                ratio = half_up(required * BP, max(1, affordable))
                threat_per_dollar = half_up(durability, max(1, income))
                funded_damage = half_up(income * best["sustained_damage"], best["cost"])
                coverage = sorted({COUNTERS[t] for t in mechanics if money >= towers[COUNTERS[t]]["cost"]})
                rows.append({"wave": wave_no, "enemy_count": enemy_count,
                             "composition": composition,
                             "effective_durability": durability,
                             "peak_five_second_durability": peak, "full_clear_kill_income": income,
                             "threat_per_income_dollar": threat_per_dollar,
                             "income_funded_sustained_damage": funded_damage,
                             "purchasing_power_before_wave": money,
                             "affordable_sustained_damage": affordable,
                             "specialist_coverage": coverage,
                             "required_damage": required, "required_to_affordable_bp": ratio})
                money += income
            diff_maps[map_id] = rows
        report["difficulties"][diff_name] = diff_maps
    return report


def checks(report: dict) -> list[str]:
    failures = []
    for difficulty, maps in report["difficulties"].items():
        for map_id, waves in maps.items():
            for row, (low, high) in zip(waves, RATIO_BANDS):
                ratio = row["required_to_affordable_bp"]
                if not low <= ratio <= high:
                    failures.append(f"{difficulty}/{map_id}/wave_{row['wave']}: {ratio}bp outside {low}..{high}")
    return failures


def write_docs(report: dict) -> None:
    lines = ["# Campaign challenge fixtures", "",
             "Generated by `python3 tools/balance/challenge_fixtures.py --write-docs`.", "",
             "Durability includes HP, shields, and broad mechanic threat weights. Peak is the busiest inclusive five-second spawn window. Purchasing power is starting cash plus prior full-clear kill income; flawless bonuses are intentionally excluded. Affordable damage buys repeated copies of the most cost-efficient sustained base tower. Income DPS shows the sustained damage that a wave's income funds at that tower's damage-per-dollar rate. Threat/$ connects composition durability to its payout. Specialist coverage lists affordable counters required by that wave. Ratios and multipliers are integer basis points; counts, damage, threat, and money columns are integers. Enemy durability is rounded half-up once after the spawn multiplier, matching the fixture's runtime-spawn boundary.", "",
             "## Acceptance bands", "",
             "The phase-specific envelopes allow specialist introduction spikes on waves 2 and 4, then tighten through practice and the final exam. A ratio of 10,000 bp means required and affordable DPS are equal.", "",
             "| Wave | Minimum ratio (bp) | Maximum ratio (bp) |", "|---:|---:|---:|"]
    lines += [f"| {wave} | {low} | {high} |" for wave, (low, high) in enumerate(RATIO_BANDS, 1)]
    lines.append("")
    for difficulty, maps in report["difficulties"].items():
        lines += [f"## {difficulty.title()}", ""]
        for map_id, waves in maps.items():
            lines += [f"### {map_id}", "", "| Wave | Enemies | Types | Threat | Peak 5s | Income | Threat/$ | Income DPS | Pre-wave $ | Affordable DPS | Specialists | Req. DPS | Ratio (bp) |",
                      "|---:|---:|:---|---:|---:|---:|---:|---:|---:|---:|:---|---:|---:|"]
            for r in waves:
                kinds = ", ".join(f"{kind}×{count}" for kind, count in r["composition"].items())
                lines.append(f"| {r['wave']} | {r['enemy_count']} | {kinds} | {r['effective_durability']} | {r['peak_five_second_durability']} | {r['full_clear_kill_income']} | {r['threat_per_income_dollar']} | {r['income_funded_sustained_damage']} | {r['purchasing_power_before_wave']} | {r['affordable_sustained_damage']} | {', '.join(r['specialist_coverage']) or 'none'} | {r['required_damage']} | {r['required_to_affordable_bp']} |")
            lines.append("")
    (ROOT / "docs/challenge_fixtures.md").write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write-docs", action="store_true")
    args = parser.parse_args()
    report = build_report()
    if args.write_docs:
        write_docs(report)
    failures = checks(report)
    if args.check:
        for failure in failures:
            print("CHALLENGE REGRESSION " + failure, file=sys.stderr)
        return bool(failures)
    if not args.write_docs:
        report["failures"] = failures
        print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
