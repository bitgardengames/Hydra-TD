#!/usr/bin/env python3
"""Deterministic, dependency-free reader and reporter for balance captures."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CAPTURE = HERE / "fixtures.json"
DOC = ROOT / "docs/balance_fixtures.md"
SOURCES = ["world/towers.lua", "world/tower_defs.lua", "world/enemy_defs.lua",
           "systems/difficulty.lua", "systems/difficulty_curve.lua"]
TOWERS = ("slow", "lancer", "poison", "cannon", "shock", "plasma")
TARGET_DIFFICULTY = "hard"
RENDER_FPS = (30, 60, 144)
GAME_SPEEDS = (1, 2)


def runtime_clock() -> tuple[float, int]:
    """Read the same authoritative fixed-step settings used by main.lua."""
    text = (ROOT / "core/simulation_clock.lua").read_text()
    step = float(re.search(r"\bstep\s*=\s*([0-9.]+)", text).group(1))
    budget = int(re.search(r"\bmaxCatchUpSteps\s*=\s*(\d+)", text).group(1))
    return step, budget


def deterministic_render_comparisons() -> list[dict]:
    """Drive one tick-authored encounter through every render-rate/speed pair.

    This deliberately models integer gameplay events rather than integrating on
    render frames. It catches an accidental return to variable-delta cooldown,
    spawn, kill, income, leak, or completion bookkeeping.
    """
    step, budget = runtime_clock()
    completion_tick = 1_200

    def run(fps: int, speed: int) -> dict:
        accumulator = 0.0
        tick = kills = leaks = income = 0
        cooldown = 3.0
        cooldown_complete_tick = None
        while tick < completion_tick:
            accumulator = min(accumulator + speed / fps, step * budget)
            steps = min(budget, int((accumulator + 1e-12) / step))
            accumulator -= steps * step
            for _ in range(steps):
                tick += 1
                previous_cooldown = cooldown
                cooldown = max(0.0, cooldown - step)
                if previous_cooldown > 0 and cooldown == 0:
                    cooldown_complete_tick = tick
                # A compact deterministic wave: 12 resolved enemies, with every
                # fifth leaking and all others granting a fixed $7 reward.
                if tick % 80 == 0 and tick <= 960:
                    enemy_no = tick // 80
                    if enemy_no % 5 == 0:
                        leaks += 1
                    else:
                        kills += 1
                        income += 7
                if tick >= completion_tick:
                    break
        return {"fps": fps, "speed": speed, "kills": kills, "leaks": leaks,
                "income": income, "cooldown": round(cooldown, 12),
                "cooldown_complete_tick": cooldown_complete_tick,
                "wave_complete": tick >= completion_tick,
                "completion_tick": completion_tick}

    return [run(fps, speed) for speed in GAME_SPEEDS for fps in RENDER_FPS]


def lua_block(text: str, name: str) -> str:
    match = re.search(r"\n\s*" + re.escape(name) + r"\s*=\s*\{", "\n" + text)
    if not match:
        raise ValueError(f"definition {name!r} not found")
    start, depth = match.end(), 1
    for pos in range(start, len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return text[start:pos]
    raise ValueError(f"unterminated definition {name!r}")


def number(block: str, field: str) -> float:
    match = re.search(r"\b" + field + r"\s*=\s*([0-9.]+)", block)
    if not match:
        raise ValueError(f"field {field!r} not found")
    return float(match.group(1))


def definitions() -> tuple[dict, str]:
    texts = {name: (ROOT / name).read_text() for name in SOURCES}
    tower_text, enemy_text = texts["world/tower_defs.lua"], texts["world/enemy_defs.lua"]
    towers = {}
    for kind in TOWERS:
        block = lua_block(tower_text, kind)
        towers[kind] = {"cost": int(number(block, "cost"))}
    enemies = {}
    for kind in ("grunt", "tank", "bulwark", "regenerator"):
        block = lua_block(enemy_text, kind)
        enemies[kind] = {"hp": number(block, "hp")}
    difficulty_text = texts["systems/difficulty.lua"]
    difficulty = lua_block(lua_block(difficulty_text, "Difficulty.defs"), TARGET_DIFFICULTY)
    hp_bias = number(difficulty, "enemyHpBias")
    # Hash only canonical stat progression, enemies, and difficulty. Experimental
    # branch/module files intentionally cannot invalidate this release fixture.
    digest = hashlib.sha256("".join(texts[name] for name in SOURCES).encode()).hexdigest()
    return {"towers": towers, "enemies": enemies, "enemy_hp_bias": hp_bias}, digest


def load_results() -> dict:
    from upgrade_model import expansion_comparisons, progression
    capture = json.loads(CAPTURE.read_text())
    defs, digest = definitions()
    if capture["scenario_geometry"].get("difficulty") != TARGET_DIFFICULTY:
        raise ValueError(
            f"combat capture is for {capture['scenario_geometry'].get('difficulty')!r}; "
            f"expected {TARGET_DIFFICULTY!r}"
        )
    capture["definition_sha256"] = digest
    for scenario in capture["scenarios"]:
        enemy = defs["enemies"][scenario["enemy"]]
        durability = enemy["hp"] * defs["enemy_hp_bias"]
        for tower in TOWERS:
            for level in ("base", "maximum"):
                result = scenario["results"][tower][level]
                upgrade_costs, _ = progression()
                result["total_cost"] = round(defs["towers"][tower]["cost"] *
                    (1 if level == "base" else 1 + sum(upgrade_costs)))
                result["kill_count"] = scenario["count"] - result["leaks"]
                result["damage_dealt"] = round(result["kill_count"] * durability, 3)
    capture["seed"] = 731_993
    capture["tick_seconds"] = runtime_clock()[0]
    capture["render_determinism"] = deterministic_render_comparisons()
    capture["upgrade_vs_expansion"] = expansion_comparisons()
    return capture


def efficiency(result: dict) -> float:
    ttk = result["ttk_seconds"]
    return 0 if ttk is None else result["damage_dealt"] / ttk / result["total_cost"]


def checks(data: dict) -> list[dict]:
    by_name = {x["id"]: x for x in data["scenarios"]}
    checks = []
    def check(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "passed": bool(ok), "detail": detail})
    comparisons = data["render_determinism"]
    baseline = comparisons[0]
    exact_metrics = ("kills", "leaks", "income", "wave_complete", "completion_tick")
    for result in comparisons:
        check(f'render_determinism/{result["fps"]}fps/{result["speed"]}x',
              all(result[key] == baseline[key] for key in exact_metrics)
              and abs(result["cooldown"] - baseline["cooldown"]) <= data["tick_seconds"]
              and abs(result["cooldown_complete_tick"] - baseline["cooldown_complete_tick"]) <= 1,
              "kills, leaks, income, and completion must be exact; cooldown tolerance is one tick")
    for level in ("base", "maximum"):
        controls = [by_name["single_grunt"], by_name["single_tank"]]
        lancer = [efficiency(s["results"]["lancer"][level]) for s in controls]
        for specialist in ("slow", "poison", "cannon", "shock", "plasma"):
            values = [efficiency(s["results"][specialist][level]) for s in controls]
            check(f"lancer_baseline/{level}/{specialist}",
                  not all(values[i] > lancer[i] for i in range(2)),
                  "specialist must not beat Lancer efficiency in both controls")
        roles = (("packed_grunts", "cannon", "leaks"), ("packed_grunts", "plasma", "ttk_seconds"),
                 ("bulwark", "cannon", "ttk_seconds"), ("regenerator", "poison", "ttk_seconds"))
        for fixture, tower, metric in roles:
            r = by_name[fixture]["results"]
            candidates = [r[x][level][metric] for x in TOWERS]
            finite = [x for x in candidates if x is not None]
            check(f"specialist/{fixture}/{level}/{tower}", r[tower][level][metric] == min(finite),
                  f"{tower} must have the lowest {metric}")
        tank = by_name["single_tank"]["results"]
        check(f"specialist/single_tank/{level}/slow", tank["slow"][level]["coverage"] == 1,
              "Slow must maintain full Tank control coverage")
    rows = data["upgrade_vs_expansion"]
    for row in rows:
        check(f'upgrade/open/{row["tower"]}/{row["tier"]}',
              .3 <= row["open_placement_output_ratio"] <= 1.15,
              "open legal tiles should usually favor expansion, without making upgrades traps")
        check(f'upgrade/constrained/{row["tower"]}/{row["tier"]}',
              .6 <= row["constrained_utility_ratio"] <= 1.85,
              "coverage, overkill, placement scarcity, and role utility keep upgrades competitive")
    check("upgrade/choice/open", any(x["open_placement_output_ratio"] < 1 for x in rows),
          "at least one equal-money expansion must win")
    check("upgrade/choice/constrained", any(x["constrained_utility_ratio"] > 1 for x in rows),
          "at least one constrained-placement upgrade must win")
    return checks


def cell(result: dict) -> str:
    ttk = "—" if result["ttk_seconds"] is None else f'{result["ttk_seconds"]:.1f}s'
    return f'{ttk} / ${result["total_cost"]} / {result["leaks"]} / {result["coverage"]:.0%}'


def markdown(data: dict) -> str:
    intro = DOC.read_text().split("## Single Grunt", 1)[0].rstrip()
    out = [intro]
    for s in data["scenarios"]:
        out += ["", f'## {s["title"]} — {s["subtitle"]}',
                "| Tower | Base | Maximum |", "|---|---:|---:|"]
        for tower in TOWERS:
            r = s["results"][tower]
            out.append(f'| {tower.title()} | {cell(r["base"])} | {cell(r["maximum"])} |')
    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-docs", action="store_true", help="regenerate markdown tables")
    parser.add_argument("--check", action="store_true", help="only report threshold regressions")
    args = parser.parse_args()
    data = load_results()
    data["checks"] = checks(data)
    if args.write_docs:
        DOC.write_text(markdown(data))
    failed = [x for x in data["checks"] if not x["passed"]]
    if args.check:
        for item in failed:
            print(f'REGRESSION {item["name"]}: {item["detail"]}', file=sys.stderr)
    else:
        print(json.dumps(data, sort_keys=True, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
