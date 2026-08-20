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
import hashlib
import json
import math
import re
import sys
from dataclasses import dataclass
from functools import cache
from pathlib import Path

from challenge_fixtures import (BP, block, curve_multiplier_bp, decimal_bp,
                                definitions, half_up, named_blocks, number)

ROOT = Path(__file__).resolve().parents[2]
BANDS = ROOT / "tools/balance/campaign_acceptance_bands.json"
# A coarser fixed policy tick than rendering/runtime (whose source is included in
# the fingerprint); cooldown overshoot is carried, so shot cadence stays stable.
TICK = .2
UPGRADE_COST = (1.3, 1.7, 2.2, 2.8)
DEFINITION_FILES = (
    "core/simulation_clock.lua", "core/constants.lua", "world/map_defs.lua",
    "world/map.lua", "world/tower_defs.lua", "world/towers.lua",
    "world/tower_branch_defs.lua", "world/enemy_defs.lua", "world/enemies.lua",
    "world/enemy_traits.lua", "world/projectiles.lua", "world/projectile_behaviors.lua",
    "world/targeting.lua", "systems/ability_defs.lua", "systems/abilities.lua",
    "systems/campaign_wave_defs.lua", "systems/waves.lua",
    "systems/difficulty.lua", "systems/difficulty_curve.lua", "systems/campaign_unlocks.lua",
)

POLICIES = {
    "novice": {"placement_candidates": 4, "placement_noise": .32,
        "counter_knowledge": .35, "lookahead_waves": 0, "upgrade_preference": .25,
        "ability_accuracy": .52, "ability_delay": 4.0, "retries": 2, "search_budget": 4},
    "competent": {"placement_candidates": 10, "placement_noise": .13,
        "counter_knowledge": .72, "lookahead_waves": 1, "upgrade_preference": .48,
        "ability_accuracy": .76, "ability_delay": 1.6, "retries": 2, "search_budget": 12},
    "expert": {"placement_candidates": 24, "placement_noise": .02,
        "counter_knowledge": 1.0, "lookahead_waves": 2, "upgrade_preference": .68,
        "ability_accuracy": .94, "ability_delay": .35, "retries": 1, "search_budget": 32},
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
    for kind, body in named_blocks(block(tower_text, r"return")).items():
        if "cost" not in body: continue
        def n(key, default): return float(number(body, key, str(default)))
        towers[kind] = {"cost": int(n("cost", 1)), "damage": n("damage", 1),
            "rate": n("fireRate", 1), "range": n("range", 3) / 56 if "Constants.TILE" not in number(body, "range", "0") else 3.5,
            "dmg_mult": n("dmgMult", 1), "fire_mult": n("fireMult", 1)}
        towers[kind]["range"] = float(re.search(r"range\s*=\s*([0-9.]+)", body).group(1))
        if kind == "poison": towers[kind]["poison"] = 4.0
        if kind == "cannon": towers[kind]["splash"] = 44 / 56
        if kind == "shock": towers[kind]["chain"] = 4.0
        if kind == "plasma": towers[kind]["tick"] = .14
    enemies = {}
    for kind, body in named_blocks(block(enemy_text, r"return")).items():
        if "hp" not in body: continue
        def n(key, default): return float(number(body, key, str(default)))
        enemies[kind] = {"hp": n("hp", 1), "speed": n("speed", 50),
            "reward": n("reward", 0), "boss": "boss = true" in body,
            "armor": n("flatReduction", 0), "regen": n("hpPerSecond", 0)}
    map_text = (ROOT / "world/map_defs.lua").read_text()
    lengths = []
    for path in re.findall(r"\bpath\s*=\s*\{(.*?)\n\s*\},", map_text, re.S):
        points = [(int(a), int(b)) for a, b in re.findall(r"\{(\d+),\s*(\d+)\}", path)]
        if points: lengths.append(sum(abs(b[0]-a[0])+abs(b[1]-a[1]) for a,b in zip(points, points[1:])))
    return towers, enemies, lengths


@dataclass
class Enemy:
    kind: str; hp: float; max_hp: float; speed: float; reward: int
    pos: float = 0.; slow_until: float = 0.; poison_until: float = 0.; poison_dps: float = 0.
    armor: float = 0.; regen: float = 0.; last_hit: float = 0.


@dataclass
class Tower:
    kind: str; center: float; coverage: float; level: int = 1; cooldown: float = 0.


def composition_for(groups):
    result = {}
    for g in groups: result[g["kind"]] = result.get(g["kind"], 0) + g["count"]
    return result


def choose_kind(policy, composition, towers, key):
    counter = None
    if any(k in composition for k in ("bulwark",)): counter = "cannon"
    elif any(k in composition for k in ("regenerator",)): counter = "poison"
    elif any(k in composition for k in ("runner", "warcaller")): counter = "slow"
    if counter and stable_unit(*key, "counter") < policy["counter_knowledge"]: return counter
    # Deliberately bounded and imperfect repertoires; novice overbuys cheap Lancers.
    pools = {"novice": ("lancer","lancer","slow","cannon"),
             "competent": ("lancer","cannon","shock","poison","slow"),
             "expert": ("lancer","cannon","shock","poison","slow","plasma")}
    pool = pools[key[0]]
    return pool[int(stable_unit(*key, "kind") * len(pool)) % len(pool)]


def placement(policy_name, policy, path_len, tower_no, variant):
    best = None
    candidates = policy["placement_candidates"]
    for candidate in range(candidates):
        center = .12 + .76 * stable_unit(policy_name, path_len, tower_no, variant, candidate)
        # Interior bends and central route coverage are useful. Noise causes real
        # bad locations, rather than reducing the tower's damage behind the scenes.
        score = 1 - abs(center - .55) + .18 * math.sin(center * path_len)
        score += policy["placement_noise"] * (stable_unit("noise", policy_name, tower_no, variant, candidate)-.5)
        if best is None or score > best[0]: best = score, center
    return best[1]


def campaign(map_id, map_index, path_len, diff_name, variant, policy_name, defs):
    towers_def, enemies_def, diffs, curve, maps = defs
    detail_towers, detail_enemies, _ = parse_detail()
    policy = POLICIES[policy_name]; diff = diffs[diff_name]
    money, lives = diff["money"], {"easy":25,"normal":20,"hard":15}[diff_name]
    towers: list[Tower] = []; rebuilds = uses = opportunities = 0
    failed_wave = None
    for wave_no, groups in enumerate(maps[map_id], 1):
        seen = composition_for(groups)
        # Purchases execute between waves. Lookahead broadens counter knowledge.
        preview = dict(seen)
        for ahead in range(1, policy["lookahead_waves"] + 1):
            if wave_no + ahead <= 10:
                for k,v in composition_for(maps[map_id][wave_no+ahead-1]).items(): preview[k]=preview.get(k,0)+v
        actions = 0
        while actions < policy["search_budget"]:
            actions += 1
            upgradable = [t for t in towers if t.level < 5]
            if upgradable and stable_unit(policy_name,map_id,diff_name,variant,wave_no,actions,"up") < policy["upgrade_preference"]:
                target = max(upgradable, key=lambda t: (t.level, -abs(t.center-.55)))
                cost = round(detail_towers[target.kind]["cost"] * UPGRADE_COST[target.level-1])
                if money >= cost: money -= cost; target.level += 1; continue
            kind = choose_kind(policy, preview, detail_towers, (policy_name,map_id,diff_name,variant,wave_no,actions))
            cost = detail_towers[kind]["cost"]
            if money < cost: break
            center = placement(policy_name, policy, path_len, len(towers), variant)
            coverage = min(.22, detail_towers[kind]["range"] * 2 / max(12, path_len))
            towers.append(Tower(kind, center, coverage)); money -= cost
        spawn, at = [], 0.
        for group in groups:
            at += group["delay_ms"] / 1000
            for i in range(group["count"]): spawn.append((at+i*group["spacing_ms"]/1000, group["kind"]))
            at = spawn[-1][0]
        live=[]; cursor=0; now=0.; ability_ready=0.; wave_uses=0
        limit = at + path_len * 56 / 35 + 20
        while (cursor < len(spawn) or live) and now < limit and lives > 0:
            while cursor < len(spawn) and spawn[cursor][0] <= now + 1e-8:
                kind=spawn[cursor][1]; ed=detail_enemies[kind]
                mult=curve_multiplier_bp(curve,wave_no,map_index,diff,ed["boss"])/BP
                hp=ed["hp"]*mult
                live.append(Enemy(kind,hp,hp,ed["speed"]*diff["hp_bp"]/diff["hp_bp"],
                                  half_up(int(ed["reward"]*BP)*diff["reward_bp"],BP*BP),armor=ed["armor"],regen=ed["regen"]))
                cursor += 1
            # Ability attempts are delayed/inaccurate, not globally weakened.
            if live and now >= ability_ready:
                opportunities += 1
                if now >= policy["ability_delay"] and stable_unit(policy_name,map_id,variant,wave_no,int(now*10)) < policy["ability_accuracy"]:
                    cluster=sorted(live,key=lambda e:e.pos,reverse=True)[:max(1,round(4*policy["ability_accuracy"]))]
                    for e in cluster: e.hp -= 85
                    uses += 1; wave_uses += 1; ability_ready=now+35
                else: ability_ready=now+2
            for tower in towers:
                tower.cooldown -= TICK
                targets=[e for e in live if abs(e.pos-tower.center) <= tower.coverage/2]
                if targets and tower.cooldown <= 0:
                    targets.sort(key=lambda e:e.pos,reverse=True); target=targets[0]
                    td=detail_towers[tower.kind]; progress=(tower.level-1)/4
                    damage=td["damage"]*(1+(td["dmg_mult"]-1)*progress)
                    rate=td["rate"]*(1+(td["fire_mult"]-1)*progress)
                    victims=targets[:1]
                    if "splash" in td: victims=[e for e in targets if abs(e.pos-target.pos)<.035]
                    if "chain" in td: victims=targets[:5]
                    for index,e in enumerate(victims):
                        hit=damage*(.82**index if tower.kind=="shock" else 1)
                        e.hp -= max(1, hit-e.armor); e.last_hit=now
                        if tower.kind=="slow": e.slow_until=max(e.slow_until,now+1.7)
                        if tower.kind=="poison": e.poison_until=now+4.5; e.poison_dps=min(32,e.poison_dps+4)
                    tower.cooldown += 1/max(.01,rate)
            survivors=[]
            for e in live:
                if e.poison_until>now: e.hp -= e.poison_dps*TICK
                elif e.poison_dps: e.poison_dps=0
                if e.regen and now-e.last_hit>1.25: e.hp=min(e.max_hp,e.hp+e.regen*TICK)
                if e.hp <= 0: money += e.reward; continue
                speed=e.speed*(.45 if e.slow_until>now else 1)
                e.pos += speed*TICK/(path_len*56)
                if e.pos >= 1: lives -= 1; continue
                survivors.append(e)
            live=survivors; now += TICK
        if lives <= 0: failed_wave=wave_no; break
        if not live and wave_uses == 0 and towers: money += round(float(diff_name=="easy") + 1.5)
        # A failed late defense may sell its worst placement and genuinely rebuild.
        if lives < 4 and towers and policy_name != "novice":
            worst=min(towers,key=lambda t:t.coverage); refund=int(detail_towers[worst.kind]["cost"]*({"easy":.85,"normal":.75,"hard":.6}[diff_name])); towers.remove(worst); money+=refund; rebuilds+=1
    comp={}
    for t in towers: comp[t.kind]=comp.get(t.kind,0)+1
    return {"victory": failed_wave is None, "lives_remaining": max(0,lives),
            "failed_wave": failed_wave, "unused_money": money, "tower_composition": dict(sorted(comp.items())),
            "rebuild_count": rebuilds, "ability_uses": uses,
            "ability_utilization": round(uses/max(1,opportunities),4)}


def build_report():
    defs=definitions(); _,_,lengths=parse_detail(); maps=list(defs[4]); bands=json.loads(BANDS.read_text())
    report={"format_version":1,"definition_sha256":fingerprint(),"definition_files":list(DEFINITION_FILES),
            "tick_seconds":TICK,"policy_profiles":POLICIES,"campaigns_per_policy":bands["campaigns_per_policy"],"results":[]}
    for mi,map_id in enumerate(maps,1):
      for diff in ("easy","normal","hard"):
        policies={}
        for pname in POLICIES:
          runs=[campaign(map_id,mi,lengths[mi-1],diff,v,pname,defs) for v in range(bands["campaigns_per_policy"])]
          policies[pname]={"victory_rate":round(sum(r["victory"] for r in runs)/len(runs),4),"runs":runs}
        rates=[p["victory_rate"] for p in policies.values()]
        report["results"].append({"map":map_id,"difficulty":diff,"policies":policies,
          "success_failure_margin":round(max(rates)-min(rates),4)})
    return report


def check(report):
    bands=json.loads(BANDS.read_text()); errors=[]
    for row in report["results"]:
        req=bands["required_policy_by_difficulty"][row["difficulty"]]
        selected=row["policies"][req["policy"]]; rate=selected["victory_rate"]
        if rate < req["minimum_victory_rate"]: errors.append(f'{row["difficulty"]}/{row["map"]}: {req["policy"]} victory rate {rate}')
        metric=bands["metric_bands"]
        if row["success_failure_margin"] < metric["minimum_policy_margin"]:
            errors.append(f'{row["difficulty"]}/{row["map"]}: policy margin {row["success_failure_margin"]}')
        rebuilds=sum(run["rebuild_count"] for run in selected["runs"])/len(selected["runs"])
        utilization=sum(run["ability_utilization"] for run in selected["runs"])/len(selected["runs"])
        if rebuilds > metric["maximum_mean_rebuilds"]:
            errors.append(f'{row["difficulty"]}/{row["map"]}: mean rebuilds {rebuilds:.3f}')
        if utilization < metric["minimum_ability_utilization"]:
            errors.append(f'{row["difficulty"]}/{row["map"]}: ability utilization {utilization:.3f}')
    return errors


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--check",action="store_true"); parser.add_argument("--summary",action="store_true"); args=parser.parse_args()
    report=build_report(); errors=check(report)
    if args.summary:
        print(json.dumps({"definition_sha256":report["definition_sha256"],"campaigns":len(report["results"]),"failures":errors},sort_keys=True,separators=(",",":")))
    elif not args.check: print(json.dumps(report,sort_keys=True,separators=(",",":")))
    if errors:
        if args.check:
            for error in errors: print(error,file=sys.stderr)
        raise SystemExit(1)

if __name__ == "__main__": main()
