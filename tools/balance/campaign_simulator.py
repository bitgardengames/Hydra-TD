#!/usr/bin/env python3
"""Deterministic, individual-entity campaign policy simulator.

This is intentionally an execution model, not an aggregate DPS spreadsheet:
enemies spawn and move on the authored route, towers acquire targets and fire on
cooldowns, armor/poison/slow and active abilities resolve on fixed ticks, and
money is awarded only when an entity dies.  The compact Python model mirrors the
runtime rules so it can run in CI installations which do not ship LÖVE/Lua.
"""

from __future__ import annotations

import argparse
import heapq
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Mapping, Sequence

from challenge_fixtures import BP, curve_multiplier_bp, definitions, half_up, number
from lua_source import named_entries, table_body

ROOT = Path(__file__).resolve().parents[2]
BANDS = ROOT / "tools/balance/campaign_acceptance_bands.json"
# A coarser fixed policy tick than rendering/runtime (whose source is included in
# the fingerprint); cooldown overshoot is carried, so shot cadence stays stable.
TICK = 0.2
DEFINITION_FILES = (
    "core/simulation_clock.lua",
    "core/constants.lua",
    "world/map_defs.lua",
    "world/map.lua",
    "world/tower_defs.lua",
    "world/towers.lua",
    "world/enemy_defs.lua",
    "world/enemies.lua",
    "world/enemy_traits.lua",
    "world/projectiles.lua",
    "world/projectile_behaviors.lua",
    "world/targeting.lua",
    "systems/ability_defs.lua",
    "systems/abilities.lua",
    "systems/campaign_wave_defs.lua",
    "systems/waves.lua",
    "systems/difficulty.lua",
    "systems/difficulty_curve.lua",
    "systems/campaign_unlocks.lua",
)

POLICIES = {
    "novice": {
        "placement_candidates": 4,
        "placement_noise": 0.32,
        "counter_knowledge": 0.35,
        "lookahead_waves": 0,
        "upgrade_preference": 0.25,
        "ability_accuracy": 0.52,
        "ability_delay": 4.0,
        "retries": 2,
        "search_budget": 4,
    },
    "competent": {
        "placement_candidates": 10,
        "placement_noise": 0.13,
        "counter_knowledge": 0.72,
        "lookahead_waves": 1,
        "upgrade_preference": 0.48,
        "ability_accuracy": 0.76,
        "ability_delay": 1.6,
        "retries": 2,
        "search_budget": 12,
    },
    "hard": {
        "placement_candidates": 24,
        "placement_noise": 0.02,
        "counter_knowledge": 1.0,
        "lookahead_waves": 2,
        "upgrade_preference": 0.55,
        "ability_accuracy": 0.94,
        "ability_delay": 0.35,
        "retries": 1,
        "search_budget": 32,
    },
}


def stable_unit(*parts: object) -> float:
    raw = "/".join(map(str, parts)).encode()
    return int.from_bytes(hashlib.sha256(raw).digest()[:8], "big") / 2**64


def fingerprint() -> str:
    digest = hashlib.sha256()
    for rel in DEFINITION_FILES:
        digest.update(rel.encode() + b"\0")
        digest.update((ROOT / rel).read_bytes())
    return digest.hexdigest()


@cache
def parse_detail():
    tower_text = (ROOT / "world/tower_defs.lua").read_text()
    enemy_text = (ROOT / "world/enemy_defs.lua").read_text()
    towers = {}
    tower_root = table_body(tower_text, "return", ROOT / "world/tower_defs.lua")
    for kind, body in named_entries(
        tower_root, "return", ROOT / "world/tower_defs.lua"
    ).items():
        if "cost" not in body:
            continue

        def n(key, default):
            return float(number(body, key, str(default)))

        towers[kind] = {
            "cost": int(n("cost", 1)),
            "damage": n("damage", 1),
            "rate": n("fireRate", 1),
            "range": (
                n("range", 3) / 56
                if "Constants.TILE" not in number(body, "range", "0")
                else 3.5
            ),
            "dmg_mult": n("dmgMult", 1),
            "fire_mult": n("fireMult", 1),
        }
        towers[kind]["range"] = float(
            re.search(r"range\s*=\s*([0-9.]+)", body).group(1)
        )
        if kind == "poison":
            towers[kind]["poison"] = 4.0
        if kind == "cannon":
            towers[kind]["splash"] = 44 / 56
        if kind == "shock":
            towers[kind]["chain"] = 4.0
        if kind == "plasma":
            towers[kind]["tick"] = 0.14
    enemies = {}
    enemy_root = table_body(enemy_text, "return", ROOT / "world/enemy_defs.lua")
    for kind, body in named_entries(
        enemy_root, "return", ROOT / "world/enemy_defs.lua"
    ).items():
        if "hp" not in body:
            continue

        def n(key, default):
            return float(number(body, key, str(default)))

        enemies[kind] = {
            "hp": n("hp", 1),
            "speed": n("speed", 50),
            "reward": n("reward", 0),
            "boss": "boss = true" in body,
            "armor": n("flatReduction", 0),
            "regen": n("hpPerSecond", 0),
        }
    map_text = (ROOT / "world/map_defs.lua").read_text()
    lengths = []
    for path in re.findall(r"\bpath\s*=\s*\{(.*?)\n\s*\},", map_text, re.S):
        points = [(int(a), int(b)) for a, b in re.findall(r"\{(\d+),\s*(\d+)\}", path)]
        if points:
            lengths.append(
                sum(
                    abs(b[0] - a[0]) + abs(b[1] - a[1])
                    for a, b in zip(points, points[1:])
                )
            )
    return towers, enemies, lengths


@dataclass
class Enemy:
    kind: str
    hp: float
    max_hp: float
    speed: float
    reward: int
    pos: float = 0.0
    slow_until: float = 0.0
    poison_until: float = 0.0
    poison_dps: float = 0.0
    armor: float = 0.0
    regen: float = 0.0
    last_hit: float = 0.0


@dataclass
class Tower:
    kind: str
    center: float
    coverage: float
    level: int = 1
    cooldown: float = 0.0


def select_tower_targets(
    tower: Tower,
    tower_def: Mapping[str, float],
    live: Sequence[Enemy],
) -> tuple[Enemy | None, Sequence[Enemy]]:
    """Select a primary target and only the extra targets an attack can hit."""
    primary = None
    splash_candidates = [] if "splash" in tower_def else None
    chain_candidates = [] if "chain" in tower_def else None
    coverage = tower.coverage / 2

    for live_index, enemy in enumerate(live):
        if abs(enemy.pos - tower.center) > coverage:
            continue
        if primary is None or enemy.pos > primary.pos:
            primary = enemy
        if splash_candidates is not None:
            splash_candidates.append(enemy)
        elif chain_candidates is not None:
            # Earlier live-list entries win equal-position ties, matching the
            # stable sort previously used by campaign().
            ranked = (enemy.pos, -live_index, enemy)
            if len(chain_candidates) < 5:
                heapq.heappush(chain_candidates, ranked)
            elif ranked[:2] > chain_candidates[0][:2]:
                heapq.heapreplace(chain_candidates, ranked)

    if primary is None:
        return None, ()
    if splash_candidates is not None:
        splash_targets = (
            enemy
            for enemy in splash_candidates
            if enemy is not primary and abs(enemy.pos - primary.pos) < 0.035
        )
        return primary, tuple(
            sorted(splash_targets, key=lambda enemy: enemy.pos, reverse=True)
        )
    if chain_candidates is not None:
        ranked_targets = sorted(
            chain_candidates, key=lambda item: item[:2], reverse=True
        )
        return primary, tuple(
            item[2] for item in ranked_targets if item[2] is not primary
        )
    return primary, ()


def resolve_tower_attack(
    tower: Tower,
    tower_def: Mapping[str, float],
    primary: Enemy,
    additional_targets: Sequence[Enemy],
    now: float,
) -> None:
    """Apply one tower attack and advance its cooldown."""
    progress = (tower.level - 1) / 4
    damage = tower_def["damage"] * (1 + (tower_def["dmg_mult"] - 1) * progress)
    rate = tower_def["rate"] * (1 + (tower_def["fire_mult"] - 1) * progress)

    def apply_hit(enemy: Enemy, index: int) -> None:
        hit = damage * (0.82**index if tower.kind == "shock" else 1)
        enemy.hp -= max(1, hit - enemy.armor)
        enemy.last_hit = now
        if tower.kind == "slow":
            enemy.slow_until = max(enemy.slow_until, now + 1.7)
        if tower.kind == "poison":
            enemy.poison_until = now + 4.5
            enemy.poison_dps = min(32, enemy.poison_dps + 4)

    apply_hit(primary, 0)
    for index, enemy in enumerate(additional_targets, 1):
        apply_hit(enemy, index)
    tower.cooldown += 1 / max(0.01, rate)


def composition_for(groups):
    result = {}
    for g in groups:
        result[g["kind"]] = result.get(g["kind"], 0) + g["count"]
    return result


def choose_kind(policy, composition, towers, key):
    counter = None
    if any(k in composition for k in ("bulwark",)):
        counter = "cannon"
    elif any(k in composition for k in ("regenerator",)):
        counter = "poison"
    elif any(k in composition for k in ("runner", "warcaller")):
        counter = "slow"
    # Counter knowledge should produce a rounded defense, not fill every legal
    # tile with the wave's specialist. Keep roughly one counter per three towers
    # before returning to the policy's broader repertoire.
    specialist_cap = max(1, math.ceil((len(towers) + 1) / 3))
    if (
        counter
        and sum(t.kind == counter for t in towers) < specialist_cap
        and stable_unit(*key, "counter") < policy["counter_knowledge"]
    ):
        return counter
    # Deliberately bounded and imperfect repertoires; novice overbuys cheap Lancers.
    pools = {
        "novice": ("lancer", "lancer", "slow", "cannon"),
        "competent": ("lancer", "cannon", "shock", "poison", "slow"),
        "hard": ("lancer", "cannon", "shock", "poison", "slow", "plasma"),
    }
    pool = pools[key[0]]
    return pool[int(stable_unit(*key, "kind") * len(pool)) % len(pool)]


def placement(policy_name, policy, path_len, tower_no, variant):
    best = None
    candidates = policy["placement_candidates"]
    for candidate in range(candidates):
        center = 0.12 + 0.76 * stable_unit(
            policy_name, path_len, tower_no, variant, candidate
        )
        # Interior bends and central route coverage are useful. Noise causes real
        # bad locations, rather than reducing the tower's damage behind the scenes.
        score = 1 - abs(center - 0.55) + 0.18 * math.sin(center * path_len)
        score += policy["placement_noise"] * (
            stable_unit("noise", policy_name, tower_no, variant, candidate) - 0.5
        )
        if best is None or score > best[0]:
            best = score, center
    return best[1]


def campaign(map_id, map_index, path_len, diff_name, variant, policy_name, defs):
    from upgrade_model import progression

    upgrade_cost, _ = progression()
    towers_def, enemies_def, diffs, curve, maps = defs
    detail_towers, detail_enemies, _ = parse_detail()
    policy = POLICIES[policy_name]
    diff = diffs[diff_name]
    money, lives = diff["money"], {"easy": 25, "normal": 20, "hard": 15}[diff_name]
    towers: list[Tower] = []
    rebuilds = uses = opportunities = 0
    failed_wave = None
    for wave_no, groups in enumerate(maps[map_id], 1):
        seen = composition_for(groups)
        # Purchases execute between waves. Lookahead broadens counter knowledge.
        preview = dict(seen)
        for ahead in range(1, policy["lookahead_waves"] + 1):
            if wave_no + ahead <= 10:
                for k, v in composition_for(maps[map_id][wave_no + ahead - 1]).items():
                    preview[k] = preview.get(k, 0) + v
        actions = 0
        while actions < policy["search_budget"]:
            actions += 1
            upgradable = [t for t in towers if t.level < 5]
            if (
                upgradable
                and stable_unit(
                    policy_name, map_id, diff_name, variant, wave_no, actions, "up"
                )
                < policy["upgrade_preference"]
            ):
                target = max(upgradable, key=lambda t: (t.level, -abs(t.center - 0.55)))
                cost = round(
                    detail_towers[target.kind]["cost"] * upgrade_cost[target.level - 1]
                )
                if money >= cost:
                    money -= cost
                    target.level += 1
                    continue
            kind = choose_kind(
                policy,
                preview,
                towers,
                (policy_name, map_id, diff_name, variant, wave_no, actions),
            )
            cost = detail_towers[kind]["cost"]
            if money < cost:
                # A capable player does not end preparation merely because the
                # first desired specialist is unaffordable. Fall back to the
                # cheapest useful member of that policy's repertoire.
                affordable = [
                    candidate
                    for candidate in (
                        "slow",
                        "lancer",
                        "poison",
                        "cannon",
                        "shock",
                        "plasma",
                    )
                    if candidate in detail_towers
                    and detail_towers[candidate]["cost"] <= money
                ]
                if not affordable:
                    break
                kind = (
                    "lancer"
                    if "lancer" in affordable
                    else min(
                        affordable,
                        key=lambda candidate: detail_towers[candidate]["cost"],
                    )
                )
                cost = detail_towers[kind]["cost"]
            center = placement(policy_name, policy, path_len, len(towers), variant)
            coverage = min(0.22, detail_towers[kind]["range"] * 2 / max(12, path_len))
            towers.append(Tower(kind, center, coverage))
            money -= cost
        spawn, at = [], 0.0
        for group in groups:
            at += group["delay_ms"] / 1000
            for i in range(group["count"]):
                spawn.append((at + i * group["spacing_ms"] / 1000, group["kind"]))
            at = spawn[-1][0]
        live = []
        cursor = 0
        now = 0.0
        ability_ready = 0.0
        wave_uses = 0
        limit = at + path_len * 56 / 35 + 20
        while (cursor < len(spawn) or live) and now < limit and lives > 0:
            while cursor < len(spawn) and spawn[cursor][0] <= now + 1e-8:
                kind = spawn[cursor][1]
                ed = detail_enemies[kind]
                mult = (
                    curve_multiplier_bp(curve, wave_no, map_index, diff, ed["boss"])
                    / BP
                )
                hp = ed["hp"] * mult
                live.append(
                    Enemy(
                        kind,
                        hp,
                        hp,
                        ed["speed"] * diff["hp_bp"] / diff["hp_bp"],
                        half_up(int(ed["reward"] * BP) * diff["reward_bp"], BP * BP),
                        armor=ed["armor"],
                        regen=ed["regen"],
                    )
                )
                cursor += 1
            # Ability attempts are delayed/inaccurate, not globally weakened.
            if live and now >= ability_ready:
                opportunities += 1
                if (
                    now >= policy["ability_delay"]
                    and stable_unit(
                        policy_name, map_id, variant, wave_no, int(now * 10)
                    )
                    < policy["ability_accuracy"]
                ):
                    cluster = sorted(live, key=lambda e: e.pos, reverse=True)[
                        : max(1, round(4 * policy["ability_accuracy"]))
                    ]
                    for e in cluster:
                        e.hp -= 85
                    uses += 1
                    wave_uses += 1
                    ability_ready = now + 35
                else:
                    ability_ready = now + 2
            for tower in towers:
                tower.cooldown -= TICK
                if tower.cooldown <= 0:
                    tower_def = detail_towers[tower.kind]
                    primary, additional_targets = select_tower_targets(
                        tower, tower_def, live
                    )
                    if primary is not None:
                        resolve_tower_attack(
                            tower, tower_def, primary, additional_targets, now
                        )
            survivors = []
            for e in live:
                if e.poison_until > now:
                    e.hp -= e.poison_dps * TICK
                elif e.poison_dps:
                    e.poison_dps = 0
                if e.regen and now - e.last_hit > 1.25:
                    e.hp = min(e.max_hp, e.hp + e.regen * TICK)
                if e.hp <= 0:
                    money += e.reward
                    continue
                speed = e.speed * (0.45 if e.slow_until > now else 1)
                e.pos += speed * TICK / (path_len * 56)
                if e.pos >= 1:
                    lives -= 1
                    continue
                survivors.append(e)
            live = survivors
            now += TICK
        if lives <= 0:
            failed_wave = wave_no
            break
        if not live and wave_uses == 0 and towers:
            money += round(float(diff_name == "easy") + 1.5)
        # A failed late defense may sell its worst placement and genuinely rebuild.
        if lives < 4 and towers and policy_name != "novice":
            worst = min(towers, key=lambda t: t.coverage)
            refund = int(
                detail_towers[worst.kind]["cost"]
                * ({"easy": 0.85, "normal": 0.75, "hard": 0.6}[diff_name])
            )
            towers.remove(worst)
            money += refund
            rebuilds += 1
    comp = {}
    for t in towers:
        comp[t.kind] = comp.get(t.kind, 0) + 1
    return {
        "victory": failed_wave is None,
        "lives_remaining": max(0, lives),
        "failed_wave": failed_wave,
        "unused_money": money,
        "tower_composition": dict(sorted(comp.items())),
        "rebuild_count": rebuilds,
        "ability_uses": uses,
        "ability_utilization": round(uses / max(1, opportunities), 4),
    }


def build_report():
    defs = definitions()
    _, _, lengths = parse_detail()
    maps = list(defs[4])
    bands = json.loads(BANDS.read_text())
    report = {
        "format_version": 1,
        "definition_sha256": fingerprint(),
        "definition_files": list(DEFINITION_FILES),
        "tick_seconds": TICK,
        "policy_profiles": POLICIES,
        "campaigns_per_policy": bands["campaigns_per_policy"],
        "results": [],
    }
    for mi, map_id in enumerate(maps, 1):
        for diff in ("easy", "normal", "hard"):
            policies = {}
            for pname in POLICIES:
                runs = [
                    campaign(map_id, mi, lengths[mi - 1], diff, v, pname, defs)
                    for v in range(bands["campaigns_per_policy"])
                ]
                policies[pname] = {
                    "victory_rate": round(
                        sum(r["victory"] for r in runs) / len(runs), 4
                    ),
                    "runs": runs,
                }
            rates = [p["victory_rate"] for p in policies.values()]
            report["results"].append(
                {
                    "map": map_id,
                    "difficulty": diff,
                    "policies": policies,
                    "success_failure_margin": round(max(rates) - min(rates), 4),
                }
            )
    return report


def check(report):
    bands = json.loads(BANDS.read_text())
    errors = []
    for row in report["results"]:
        req = bands["required_policy_by_difficulty"][row["difficulty"]]
        selected = row["policies"][req["policy"]]
        rate = selected["victory_rate"]
        if "minimum_victory_rate" in req and rate < req["minimum_victory_rate"]:
            errors.append(
                f'{row["difficulty"]}/{row["map"]}: {req["policy"]} victory rate {rate}'
            )
        if "maximum_victory_rate" in req and rate > req["maximum_victory_rate"]:
            errors.append(
                f'{row["difficulty"]}/{row["map"]}: {req["policy"]} victory rate {rate}'
            )
        metric = bands["metric_bands"]
        if row["success_failure_margin"] < metric["minimum_policy_margin"]:
            errors.append(
                f'{row["difficulty"]}/{row["map"]}: policy margin {row["success_failure_margin"]}'
            )
        rebuilds = sum(run["rebuild_count"] for run in selected["runs"]) / len(
            selected["runs"]
        )
        utilization = sum(run["ability_utilization"] for run in selected["runs"]) / len(
            selected["runs"]
        )
        if rebuilds > metric["maximum_mean_rebuilds"]:
            errors.append(
                f'{row["difficulty"]}/{row["map"]}: mean rebuilds {rebuilds:.3f}'
            )
        if utilization < metric["minimum_ability_utilization"]:
            errors.append(
                f'{row["difficulty"]}/{row["map"]}: ability utilization {utilization:.3f}'
            )
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    report = build_report()
    errors = check(report)
    if args.summary:
        print(
            json.dumps(
                {
                    "definition_sha256": report["definition_sha256"],
                    "campaigns": len(report["results"]),
                    "failures": errors,
                },
                sort_keys=True,
                separators=(",", ":"),
            )
        )
    elif not args.check:
        print(json.dumps(report, sort_keys=True, separators=(",", ":")))
    if errors:
        if args.check:
            for error in errors:
                print(error, file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
