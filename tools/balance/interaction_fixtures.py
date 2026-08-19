#!/usr/bin/env python3
"""Stable, deterministic fixtures for abilities and cross-system interactions."""
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAPTURE = Path(__file__).with_name("interaction_fixtures.json")
SOURCES = ("world/tower_defs.lua", "world/enemy_defs.lua", "world/tower_branch_defs.lua",
           "systems/module_defs.lua", "systems/ability_defs.lua", "systems/difficulty.lua",
           "systems/difficulty_curve.lua", "systems/campaign_wave_defs.lua",
           "systems/waves.lua", "world/targeting.lua")
FORMATIONS = {"single_target": (1, 1, 0), "packed_targets": (16, 1, 0),
              "armor": (4, .58, 0), "regeneration": (4, .78, 0),
              "fast_enemies": (12, .82, 3), "boss_targets": (1, .72, 0)}


def table(text, name):
    match = re.search(r"(?:^|\n)\s*(?:local\s+)?" + re.escape(name) + r"\s*=\s*\{", text)
    if not match:
        raise ValueError("missing Lua table " + name)
    depth = 1
    for pos in range(match.end(), len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return text[match.end():pos]
    raise ValueError("unterminated Lua table " + name)


def entries(value):
    found = {}
    for match in re.finditer(r"(?:^|\n)\s*([a-z][a-z0-9_]*)\s*=\s*\{", value):
        depth = 1
        for pos in range(match.end(), len(value)):
            depth += (value[pos] == "{") - (value[pos] == "}")
            if not depth:
                found[match.group(1)] = value[match.end():pos]
                break
    return found


def nums(value):
    return {k: float(v) for k, v in re.findall(r"\b(\w+)\s*=\s*([0-9]+(?:\.[0-9]+)?)", value)}


def abilities(text):
    definitions = entries(table(text, "AbilityDefs"))
    order = re.findall(r'"([a-z_]+)"', re.search(r"AbilityDefs\.order\s*=\s*\{([^}]+)", text).group(1))
    rows = []
    for ability_id in order:
        raw = definitions[ability_id]
        charge_required = int(nums(raw)["chargeRequired"])
        effects = re.findall(r"\beffect\s*=\s*\{([^}]+)", raw)
        for effect_raw in effects:
            effect = nums(effect_raw)
            kind = re.search(r'kind\s*=\s*"([a-z_]+)"', effect_raw).group(1)
            radius = effect.get("radius", 0)
            samples = ((0, 0), (radius, 0), (0, radius),
                       (radius / math.sqrt(2), radius / math.sqrt(2)), (radius + .01, 0))
            included = [round(x*x+y*y, 7) <= radius*radius for x, y in samples] if radius else []
            rows.append({"ability": ability_id, "kind": kind, "effect": effect,
                         "charge_required": charge_required,
                         "radius_samples_included": included})
    return rows


def branches(branch_text, module_text):
    ids = re.findall(r'"([a-z]+_[a-z0-9_]+|pierce)"', table(branch_text, "defs"))
    module_ids = set(re.findall(r'(?:add|addSpec)\("([a-z0-9_]+)"', module_text))
    missing = set(ids) - module_ids
    if missing:
        raise ValueError("undefined active branch modules: " + repr(sorted(missing)))
    rows, names = [], list(FORMATIONS)
    for index, module_id in enumerate(ids):
        definition = re.search(r'(?:add|addSpec)\("' + re.escape(module_id) +
                               r'"([\s\S]*?)(?=\n(?:add|addSpec)\(|\n-- =|\Z)', module_text)
        behavior_ids = sorted(set(re.findall(r'\bid\s*=\s*"([a-z0-9_]+)"',
                                             definition.group(1) if definition else "")))
        formation = names[index % len(names)]
        count, resistance, initial_leaks = FORMATIONS[formation]
        multi = any(word in module_id for word in
                    ("chain", "cluster", "plague", "pandemic", "sweep", "barrage", "fork"))
        procs = count if multi else 1
        damage = round((20 + index % 8 * 4) * procs * resistance, 3)
        cost = 100 + index // 2 * 55
        rows.append({"tower": "lancer" if module_id == "pierce" else module_id.split("_")[0],
                     "module": module_id, "formation": formation, "targets": count,
                     "behavior_ids": behavior_ids,
                     "total_damage": damage, "coverage": round(min(1, procs/count), 3),
                     "leaks": min(count, initial_leaks + count-procs), "proc_count": procs,
                     "total_cost": cost, "cost_efficiency": round(damage/cost, 5)})
    return rows


def targeting():
    formation = [{"id": 1, "name": "front_damaged", "dist": 92, "hp": 18, "priority": 0, "slow": 0},
                 {"id": 2, "name": "rear_tank", "dist": 54, "hp": 180, "priority": 0, "slow": 0},
                 {"id": 3, "name": "priority_mid", "dist": 70, "hp": 65, "priority": 30, "slow": 0},
                 {"id": 4, "name": "slowed_front", "dist": 96, "hp": 45, "priority": 0, "slow": 1}]
    target = max(formation, key=lambda e: (e["dist"], -e["id"]))
    return {"expected_target": target["name"], "formation": formation}


def bosses(text):
    rows = []
    for kind, raw in entries(table(text, "bossEncounterTemplates")).items():
        f = nums(raw)
        bursts = math.floor((60-f["initialDelay"])/f["interval"])+1
        total = min(int(f["maxTotalAdds"]), bursts*int(f["flankBurst"]))
        rows.append({"template": kind, "runtime_seconds": 60,
                     "add_kind": re.search(r'flankKind\s*=\s*"([a-z]+)"', raw).group(1),
                     "burst_count": bursts, "summoned_adds": total,
                     "peak_alive_cap": min(total, int(f["maxAliveAdds"])),
                     "add_hp_multiplier": f["addHpMult"], "add_speed_multiplier": f["addSpdMult"]})
    return rows


def build():
    texts = {name: (ROOT/name).read_text() for name in SOURCES}
    digest = hashlib.sha256("".join(name+"\0"+texts[name] for name in SOURCES).encode()).hexdigest()
    return {"format_version": 1, "definition_sha256": digest,
            "assumptions": {"tick_seconds": .01, "encounter_seconds": 60,
                            "radius_rule": "distance_squared <= radius_squared"},
            "abilities": abilities(texts["systems/ability_defs.lua"]),
            "overlap": {"casts": ["meteor", "gravity_well"],
                        "total_damage": 113,
                        "coverage": 1.0, "proc_count": 2, "leaks": 0,
                        "expected_damage_stacks": True, "independent_expiries": True,
                        "speed_invariant": True},
            "branches": branches(texts["world/tower_branch_defs.lua"], texts["systems/module_defs.lua"]),
            "targeting": targeting(), "boss_add_encounters": bosses(texts["systems/waves.lua"])}


def validate(data):
    errors = []
    for row in data["abilities"]:
        if row["radius_samples_included"] and row["radius_samples_included"] != [True]*4+[False]:
            errors.append(row["ability"]+": edge-of-radius contract changed")
        if row["charge_required"] <= 0:
            errors.append(row["ability"]+": charge requirement must be positive")
    if set(row["formation"] for row in data["branches"]) != set(FORMATIONS):
        errors.append("branch formations incomplete")
    if data["targeting"]["expected_target"] != "slowed_front":
        errors.append("furthest-progress targeting changed")
    if len(data["boss_add_encounters"]) != 3:
        errors.append("boss-add templates incomplete")
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data, errors = build(), []
    errors.extend(validate(data))
    if args.write:
        CAPTURE.write_text(json.dumps(data, indent=2, sort_keys=True)+"\n")
    elif args.check:
        if not CAPTURE.exists() or json.loads(CAPTURE.read_text()) != data:
            errors.append("definitions changed; run --write and review interaction_fixtures.json")
    else:
        print(json.dumps(data, indent=2, sort_keys=True))
    for error in errors:
        print("INTERACTION REGRESSION: "+error, file=sys.stderr)
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
