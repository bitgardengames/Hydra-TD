#!/usr/bin/env python3
"""Stable, deterministic fixtures for abilities and cross-system interactions."""
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

from lua_source import named_entries, numeric_fields, table_body

ROOT = Path(__file__).resolve().parents[2]
CAPTURE = Path(__file__).with_name("interaction_fixtures.json")
SOURCES = ("world/tower_defs.lua", "world/enemy_defs.lua", "systems/module_defs.lua",
           "systems/ability_defs.lua", "systems/difficulty.lua",
           "systems/difficulty_curve.lua", "systems/campaign_wave_defs.lua",
           "systems/waves.lua", "world/targeting.lua")
def table(text, name, source="interaction source"):
    return table_body(text, name, source)


def entries(value, declaration="entry table", source="interaction source"):
    return named_entries(value, declaration, source)


nums = numeric_fields


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
            "targeting": targeting(), "boss_add_encounters": bosses(texts["systems/waves.lua"])}


def validate(data):
    errors = []
    for row in data["abilities"]:
        if row["radius_samples_included"] and row["radius_samples_included"] != [True]*4+[False]:
            errors.append(row["ability"]+": edge-of-radius contract changed")
        if row["charge_required"] <= 0:
            errors.append(row["ability"]+": charge requirement must be positive")
    if data["targeting"]["expected_target"] != "slowed_front":
        errors.append("furthest-progress targeting changed")
    if len(data["boss_add_encounters"]) != 2:
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
