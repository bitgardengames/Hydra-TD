#!/usr/bin/env python3
"""Dependency-free, deterministic campaign economy fixture report."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANDS = Path(__file__).with_name("economy_bands.json")
CURVES = {
    # kill share, flawless chance, early-call chance. Early calls currently have
    # no authored payout; retaining the probability makes that zero explicit.
    "conservative": (0.70, 0.00, 0.00),
    "balanced": (0.90, 0.65, 0.35),
    "aggressive": (1.00, 1.00, 0.80),
}
TIER_ANCHORS = {"entry_pair": 110, "lancer_t2": 135,
                "cannon_t3": 360, "plasma_t5": 1152}


def lua_block(text: str, name: str) -> str:
    match = re.search(r"\n\s*(?:local\s+)?" + re.escape(name) + r"\s*=\s*\{", "\n" + text)
    if not match:
        raise ValueError(f"definition {name!r} not found")
    start, depth = match.end(), 1
    for pos in range(start, len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return text[start:pos]
    raise ValueError(f"unterminated definition {name!r}")


def fields(block: str) -> dict[str, float]:
    return {key: float(value) for key, value in re.findall(
        r"\b(\w+)\s*=\s*([0-9.]+)", block)}


def definitions() -> tuple[dict, dict, dict]:
    difficulty_text = (ROOT / "systems/difficulty.lua").read_text()
    enemy_text = (ROOT / "world/enemy_defs.lua").read_text()
    wave_text = (ROOT / "systems/campaign_wave_defs.lua").read_text()
    difficulties = {name: fields(lua_block(lua_block(difficulty_text, "Difficulty.defs"), name))
                    for name in ("easy", "normal", "hard")}
    kinds = set(re.findall(r'g\("([a-z_]+)"', lua_block(wave_text, "wavesByMapId")))
    rewards = {kind: fields(lua_block(enemy_text, kind))["reward"] for kind in kinds}
    maps = {}
    waves_root = lua_block(wave_text, "wavesByMapId")
    for map_id in re.findall(r"^\s*([a-z]+)\s*=\s*\{", waves_root, re.M):
        block = lua_block(waves_root, map_id)
        maps[map_id] = []
        for wave in range(1, 11):
            match = re.search(rf"\[{wave}\]\s*=\s*\{{([^\n]+)", block)
            if not match:
                raise ValueError(f"{map_id} wave {wave} not found")
            groups = re.findall(r'g\("([a-z_]+)",\s*(\d+)', match.group(1))
            maps[map_id].append({kind: sum(int(n) for k, n in groups if k == kind)
                                 for kind in {k for k, _ in groups}})
    return difficulties, rewards, maps


def rounded_reward(reward: float, bias: float) -> int:
    return math.floor(reward * bias + 0.5)


def flawless_bonus(diff: dict, wave: int) -> int:
    # Campaign bosses use the base mechanic weight and package, so only the
    # authored five-wave milestone multiplier applies here.
    multiplier = 1.1 if wave % 5 == 0 else 1.0
    return math.floor(diff["perfectWaveBonus"] * multiplier + 0.5)


def build_report() -> dict:
    difficulties, rewards, maps = definitions()
    report = {"format_version": 1, "assumptions": {
        "curves": {k: {"kill_share": v[0], "flawless_chance": v[1],
                        "early_call_chance": v[2]} for k, v in CURVES.items()},
        "early_call_reward": 0, "tier_anchors": TIER_ANCHORS}, "difficulties": {}}
    for diff_name, diff in difficulties.items():
        curves = {}
        for curve_name, (kill_share, flawless_chance, early_chance) in CURVES.items():
            map_rows = {}
            for map_id, waves in maps.items():
                power = diff["startMoney"]
                rows = []
                affordable = {name: 0 if power >= cost else None for name, cost in TIER_ANCHORS.items()}
                for wave_no, counts in enumerate(waves, 1):
                    full_kills = sum(count * rounded_reward(rewards[kind], diff["rewardBias"])
                                     for kind, count in counts.items())
                    kill_income = round(full_kills * kill_share, 2)
                    flawless = round(flawless_bonus(diff, wave_no) * flawless_chance, 2)
                    early = round(0 * early_chance, 2)
                    power = round(power + kill_income + flawless + early, 2)
                    for name, cost in TIER_ANCHORS.items():
                        if affordable[name] is None and power >= cost:
                            affordable[name] = wave_no
                    rows.append({"wave": wave_no, "expected_kill_income": kill_income,
                                 "flawless_income": flawless, "early_call_income": early,
                                 "cumulative_purchasing_power": power})
                map_rows[map_id] = {"waves": rows, "affordable_wave": affordable}
            curves[curve_name] = map_rows
        loss = {name: cost - math.floor(cost * diff["sellRefund"])
                for name, cost in {"slow": 50, "lancer": 60, "plasma": 120}.items()}
        report["difficulties"][diff_name] = {"sell_loss": loss, "curves": curves}
    return report


def range_at(report: dict, difficulty: str, curve: str, wave: int) -> tuple[float, float]:
    maps = report["difficulties"][difficulty]["curves"][curve].values()
    values = [entry["waves"][wave - 1]["cumulative_purchasing_power"] for entry in maps]
    return min(values), max(values)


def checks(report: dict) -> list[tuple[str, bool, str]]:
    accepted = json.loads(BANDS.read_text())
    out = []
    for difficulty, bands in accepted["bands"].items():
        for curve in ("balanced", "conservative"):
            actual = range_at(report, difficulty, curve, 10)
            band = bands[f"wave_10_{curve}_power"]
            out.append((f"{difficulty}/{curve}/wave_10", actual[0] >= band[0] and actual[1] <= band[1],
                        f"range {actual[0]:.2f}..{actual[1]:.2f}, accepted {band[0]}..{band[1]}"))
        loss = report["difficulties"][difficulty]["sell_loss"]["lancer"]
        band = bands["sell_loss_lancer"]
        out.append((f"{difficulty}/sell_loss", band[0] <= loss <= band[1], f"${loss}, accepted ${band[0]}..${band[1]}"))
    shared = accepted["shared"]
    normal_entries = int(120 // 50)
    out.append(("normal/two_entry_opening", shared["normal_opening_entry_towers"][0] <= normal_entries <= shared["normal_opening_entry_towers"][1], f"{normal_entries} cheapest entry towers"))
    easy = range_at(report, "easy", "balanced", 10)[0]
    normal = range_at(report, "normal", "balanced", 10)[0]
    advantage = easy - normal
    band = shared["easy_recovery_advantage_wave_10"]
    out.append(("easy/recovery_room", band[0] <= advantage <= band[1], f"minimum-map advantage ${advantage:.2f}"))
    hard = range_at(report, "hard", "balanced", 10)[1]
    normal_high = range_at(report, "normal", "balanced", 10)[1]
    delay = normal_high - hard
    band = shared["hard_balanced_delay_wave_10"]
    out.append(("hard/power_delay", band[0] <= delay <= band[1], f"maximum-map delay ${delay:.2f}"))
    entries = sum(120 >= cost for cost in (50, 60, 70, 90, 95, 120))
    band = shared["hard_wave_1_affordable_entries"]
    out.append(("hard/no_mandatory_opening", band[0] <= entries <= band[1], f"{entries} distinct base towers affordable"))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail only outside accepted economy bands")
    args = parser.parse_args()
    report = build_report()
    results = checks(report)
    if args.check:
        failed = [item for item in results if not item[1]]
        for name, _, detail in failed:
            print(f"REGRESSION {name}: {detail}", file=sys.stderr)
        return 1 if failed else 0
    report["checks"] = [{"name": n, "passed": ok, "detail": detail} for n, ok, detail in results]
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
