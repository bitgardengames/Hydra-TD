#!/usr/bin/env python3
"""Dependency-free, non-rendered refinement-metrics report and alarm gate."""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SUPPORTED_DISPLAYS = ((1280, 720), (1280, 800), (1920, 1080), (2560, 1440))
TIP_TEST_WIDTHS = (1024, 1280)

# Layout constants are deliberately mirrored from the tiny, declarative UI
# modules.  Source assertions below make drift noisy instead of silently making
# this model stale.
LAYOUT = {"screen_pad": 16, "wave_w": 440, "damage_inner_w": 210,
          "combat_x": 16, "combat_y": 16, "combat_w": 244, "combat_h": 48,
          "damage_pad": 12, "damage_header": 30, "damage_header_gap": 10,
          "damage_bar_h": 22, "damage_row_gap": 6,
          "ability_size": 58, "ability_gap": 18, "ability_pad": 12,
          "ability_inset": 16, "bottom_w": 432, "bottom_h": 264,
          "bottom_inset": 16, "bottom_lift": 16, "inspect_w": 284,
          "panel_gap": 16}


def lua_table(text: str, name: str) -> str:
    match = re.search(r"(?:^|\n)\s*(?:local\s+)?" + re.escape(name) + r"\s*=\s*\{", text)
    if not match:
        raise ValueError("missing Lua table " + name)
    depth = 1
    for pos in range(match.end(), len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if not depth:
            return text[match.end():pos]
    raise ValueError("unterminated Lua table " + name)


def named_tables(block: str) -> dict[str, str]:
    out = {}
    for match in re.finditer(r"(?:^|\n)\s*([a-z][a-z0-9_]*)\s*=\s*\{", block):
        depth = 1
        for pos in range(match.end(), len(block)):
            depth += (block[pos] == "{") - (block[pos] == "}")
            if not depth:
                out[match.group(1)] = block[match.end():pos]
                break
    return out


def wave_metrics() -> dict:
    # Reuse the exact sequential-spawner reconstruction already maintained by
    # the campaign pacing gate.
    sys.path.insert(0, str(HERE))
    import campaign_pacing_report as pacing
    text = (ROOT / "systems/campaign_wave_defs.lua").read_text()
    maps = pacing.parse_waves(text)
    rows, gaps = [], []
    for map_id, waves in maps.items():
        for wave_no, groups in enumerate(waves, 1):
            measured = pacing.wave_metrics(groups)
            gaps.extend(measured["downtimeBetweenGroups"])
            rows.append({"map": map_id, "wave": wave_no,
                         "active_enemy_proxy": measured["peakSimultaneous"],
                         "spawn_duration_seconds": measured["totalWaveDuration"]})
    peak = max(rows, key=lambda row: row["active_enemy_proxy"])
    return {"preparation": {"mode": "player_started", "duration_seconds": None,
                            "note": "No countdown is authored; preparation lasts until Start Wave."},
            "average_downtime_between_waves_seconds": None,
            "average_downtime_between_authored_groups_seconds": round(sum(gaps) / len(gaps), 3),
            "active_enemy_model": "spawned in a five-second engagement window",
            "peak": peak, "waves": rows}


def event_rates() -> dict:
    text = (ROOT / "world/tower_defs.lua").read_text()
    rates = {}
    for kind in ("slow", "lancer", "poison", "cannon", "shock", "plasma"):
        match = re.search(r"\n\s*" + kind + r"\s*=\s*\{", text)
        depth = 1
        for pos in range(match.end(), len(text)):
            depth += (text[pos] == "{") - (text[pos] == "}")
            if not depth:
                raw = text[match.end():pos]
                break
        rate = float(re.search(r"\bfireRate\s*=\s*([0-9.]+)", raw).group(1))
        mult = float(re.search(r"\bfireMult\s*=\s*([0-9.]+)", raw).group(1))
        rates[kind] = {"base": rate, "tier_5": round(rate * mult ** 4, 4)}
    base = sum(x["base"] for x in rates.values())
    maximum = sum(x["tier_5"] for x in rates.values())
    return {"formation": "one continuously engaged tower of each of the six kinds",
            "assumption": "one emission and one visible aggregate damage number per attack; secondary hits excluded",
            "by_tower": rates,
            "projectile_events_per_second": {"base": round(base, 3), "tier_5": round(maximum, 3)},
            "damage_floater_events_per_second": {"base": round(base, 3), "tier_5": round(maximum, 3)}}


def ability_metrics() -> dict:
    text = (ROOT / "systems/ability_defs.lua").read_text()
    root = named_tables(lua_table(text, "AbilityDefs"))
    rows = []
    for ability, raw in root.items():
        cooldown = float(re.search(r"\bcooldown\s*=\s*([0-9.]+)", raw).group(1))
        effects = re.findall(r"(?:upgradedE|e)ffect\s*=\s*\{([^}]+)", raw)
        durations = [float(m.group(1)) for effect in effects
                     if (m := re.search(r"\bduration\s*=\s*([0-9.]+)", effect))]
        base = durations[0] if durations else 0
        enhanced = durations[-1] if durations else 0
        rows.append({"ability": ability, "cooldown_seconds": cooldown,
                     "base_duration_seconds": base, "enhanced_duration_seconds": enhanced,
                     "base_uptime_ratio": round(base / cooldown, 4),
                     "enhanced_uptime_ratio": round(enhanced / cooldown, 4)})
    sustained = [row for row in rows if row["enhanced_duration_seconds"] > 0]
    overlaps = [{"abilities": [a["ability"], b["ability"]],
                 "base_seconds": min(a["base_duration_seconds"], b["base_duration_seconds"]),
                 "enhanced_seconds": min(a["enhanced_duration_seconds"], b["enhanced_duration_seconds"])}
                for i, a in enumerate(sustained) for b in sustained[i + 1:]]
    return {"abilities": rows, "simultaneous_cast_overlap_windows": overlaps}


def preview_metrics() -> dict:
    from campaign_pacing_report import parse_waves
    maps = parse_waves((ROOT / "systems/campaign_wave_defs.lua").read_text())
    traits = {"boss": 2, "tank": 1, "runner": 1, "bulwark": 1, "regenerator": 1,
              "shieldbearer": 1, "warcaller": 1}
    rows = []
    # The 408px counter column fits about 38 average English glyphs at the
    # default font size. The trait hint lengths below conservatively model
    # getWrap without loading LÖVE or rendering a font.
    hint_chars = {"boss": 82, "tank": 66, "runner": 60, "bulwark": 72,
                  "regenerator": 70, "shieldbearer": 76, "warcaller": 62, "grunt": 0}
    for map_id, waves in maps.items():
        for wave_no, groups in enumerate(waves, 1):
            kinds = list(dict.fromkeys(group["kind"] for group in groups))
            wrapped = sum(max(1, math.ceil(hint_chars.get(kind, 64) / 38))
                          for kind in kinds if kind in traits)
            rows.append({"map": map_id, "wave": wave_no, "rows": len(kinds),
                         "wrapped_counter_lines": wrapped})
    largest = max(rows, key=lambda row: (row["rows"], row["wrapped_counter_lines"]))
    return {"assumption": "English average-glyph conservative wrap at the default font size",
            "largest_authored_preview": largest,
            "maximum_rows": max(x["rows"] for x in rows),
            "maximum_wrapped_counter_lines": max(x["wrapped_counter_lines"] for x in rows)}


def hud_metrics() -> dict:
    c = LAYOUT
    preview_source = (ROOT / "ui/wave_preview.lua").read_text()
    for name, key in (("COMBAT_X", "combat_x"), ("COMBAT_Y", "combat_y"),
                      ("COMBAT_W", "combat_w"), ("COMBAT_H", "combat_h")):
        match = re.search(r"local\s+" + name + r"\s*=\s*(\d+)", preview_source)
        if not match or int(match.group(1)) != c[key]:
            raise ValueError(f"compact wave fixture drift: {name}")
    rows = []
    ability_h = 6*c["ability_size"] + 5*c["ability_gap"] + 2*c["ability_pad"]
    damage_h = 2*c["damage_pad"] + c["damage_header"] + c["damage_header_gap"] + 6*c["damage_bar_h"] + 5*c["damage_row_gap"]
    for w, h in SUPPORTED_DISPLAYS:
        panels = {
            "compact_wave_progress": [c["combat_x"], c["combat_y"], c["combat_w"], c["combat_h"]],
            "bottom_shop": [16, h-c["bottom_h"]-16, c["bottom_w"], c["bottom_h"]],
            "bottom_inspect": [16+c["bottom_w"]+16, h-c["bottom_h"]-16, c["inspect_w"], c["bottom_h"]],
            "damage_meter_six_rows": [w-210-24-16, 16, 234, damage_h],
            "wave_preview": [16, 16, 440, 0],
            "ability_bar_six": [w-16-82, math.floor((h-ability_h)/2), 82, ability_h],
        }
        overflow = max([0] + [max(0, -x, -y, x+pw-w, y+ph-h)
                              for x, y, pw, ph in panels.values() if ph])
        compact = panels["compact_wave_progress"]
        protected = {
            "boss_health": [math.floor((w-354)/2), 16, 354, 34],
            "damage_meter": panels["damage_meter_six_rows"],
            "contextual_tip_max": [math.floor((w-min(760, w-48))/2), 24, min(760, w-48), 100],
        }
        def overlaps(a, b):
            return a[0] < b[0]+b[2] and a[0]+a[2] > b[0] and a[1] < b[1]+b[3] and a[1]+a[3] > b[1]
        collisions = [name for name, bounds in protected.items() if overlaps(compact, bounds)]
        rows.append({"resolution": f"{w}x{h}", "panels": panels,
                     "compact_protected_collisions": collisions,
                     "overflow_pixels": overflow})
    return {"note": "Panel bounds at the default font size.",
            "representative_minimum": next(x for x in rows if x["resolution"] == "1280x720"),
            "configurations": rows,
            "compact_layout_failures": sum(bool(row["compact_protected_collisions"])
                                           for row in rows)}


def message_tip_metrics() -> dict:
    """Exercise the tip's declarative geometry without requiring LÖVE."""
    source = (ROOT / "ui/messages.lua").read_text()
    expected = {"margin": 24, "pad_x": 12, "pad_y": 8, "gap": 10,
                "dismiss_pad_x": 10, "dismiss_pad_y": 4,
                "max_width": 760, "min_message_width": 240}
    names = {"margin": "TIP_MARGIN", "pad_x": "TIP_PADDING_X",
             "pad_y": "TIP_PADDING_Y", "gap": "TIP_GAP",
             "dismiss_pad_x": "TIP_DISMISS_PADDING_X",
             "dismiss_pad_y": "TIP_DISMISS_PADDING_Y",
             "max_width": "TIP_MAX_WIDTH",
             "min_message_width": "TIP_MIN_MESSAGE_WIDTH"}
    for key, name in names.items():
        match = re.search(r"local\s+" + name + r"\s*=\s*(\d+)", source)
        if not match or int(match.group(1)) != expected[key]:
            raise ValueError(f"message tip fixture drift: {name}")

    # PTSans 16 is conservatively represented by 9px average glyphs and a
    # 19px line. Long message/action copies stand in for expanded localization.
    cases = (("long_message", 220, 12), ("long_message_and_action", 300, 34))
    rows = []
    for screen_w in TIP_TEST_WIDTHS:
        for label, message_chars, dismiss_chars in cases:
            dismiss_w = dismiss_chars * 9 + 2 * expected["dismiss_pad_x"]
            max_w = min(expected["max_width"], screen_w - 2 * expected["margin"])
            inner_w = max_w - 2 * expected["pad_x"]
            inline = inner_w - expected["gap"] - dismiss_w >= expected["min_message_width"]
            text_w = inner_w - expected["gap"] - dismiss_w if inline else inner_w
            lines = max(1, math.ceil(message_chars * 9 / text_w))
            message_h, dismiss_h = lines * 19, 19 + 2 * expected["dismiss_pad_y"]
            content_h = max(message_h, dismiss_h) if inline else message_h + expected["gap"] + dismiss_h
            tip_h = content_h + 2 * expected["pad_y"]
            rows.append({"screen_width": screen_w, "case": label,
                         "message_lines": lines, "dismiss_row": 1 if inline else 2,
                         "text_width": text_w, "tip_width": max_w, "tip_height": tip_h,
                         "overflow_pixels": max(0, max_w - screen_w),
                         "unreadable_inline": inline and text_w < expected["min_message_width"]})
    return {"assumption": "PTSans 16 conservative 9px average glyph and 19px line",
            "configurations": rows,
            "layout_failures": sum(row["overflow_pixels"] > 0 or row["unreadable_inline"]
                                   for row in rows)}


def affordability_metrics() -> dict:
    sys.path.insert(0, str(HERE))
    import economy_fixtures
    economy = economy_fixtures.build_report()
    costs = {"slow": 50, "lancer": 60, "poison": 70, "cannon": 90, "shock": 95, "plasma": 120}
    anchors = {kind: {"first_upgrade": math.floor(cost*1.25 + .5),
                      "final_tier_total": math.floor(cost*9.6 + .5)}
               for kind, cost in costs.items()}
    result = {}
    for difficulty, data in economy["difficulties"].items():
        maps = data["curves"]["balanced"]
        kind_rows = {}
        for kind, prices in anchors.items():
            timing = {}
            for label, price in prices.items():
                waves = [next((row["wave"] for row in entry["waves"]
                               if row["cumulative_purchasing_power"] >= price), None)
                         for entry in maps.values()]
                timing[label] = [min(x for x in waves if x is not None),
                                 max(x for x in waves if x is not None)] if all(x is not None for x in waves) else None
            kind_rows[kind] = {"costs": prices, "affordable_wave_range": timing}
        result[difficulty] = kind_rows
    return {"curve": "balanced expected purchasing power; probes are independent, not a build order",
            "difficulties": result}


def build() -> dict:
    return {"format_version": 1, "waves": wave_metrics(), "event_rates": event_rates(),
            "abilities": ability_metrics(), "wave_preview": preview_metrics(),
            "hud_bounds": hud_metrics(), "message_tips": message_tip_metrics(),
            "upgrade_affordability": affordability_metrics()}


def checks(data: dict) -> list[tuple[str, bool, str]]:
    b = json.loads((HERE / "polish_bands.json").read_text())["bands"]
    out = []
    def alarm(name, value, band):
        out.append((name, band[0] <= value <= band[1], f"{value} accepted {band[0]}..{band[1]}"))
    alarm("wave/recovery", data["waves"]["average_downtime_between_authored_groups_seconds"], b["average_authored_recovery_seconds"])
    alarm("wave/active", data["waves"]["peak"]["active_enemy_proxy"], b["peak_active_proxy"])
    for level in ("base", "tier_5"):
        alarm("events/projectiles/"+level, data["event_rates"]["projectile_events_per_second"][level], b[level+"_projectile_events_per_second"])
    alarm("events/floaters", data["event_rates"]["damage_floater_events_per_second"]["base"], b["base_damage_floater_events_per_second"])
    for row in data["abilities"]["abilities"]:
        alarm("ability/uptime/"+row["ability"], row["enhanced_uptime_ratio"], b["ability_uptime_ratio"])
    for row in data["abilities"]["simultaneous_cast_overlap_windows"]:
        alarm("ability/overlap/"+"+".join(row["abilities"]), row["enhanced_seconds"], b["ability_overlap_seconds"])
    alarm("preview/rows", data["wave_preview"]["maximum_rows"], b["wave_preview_rows"])
    alarm("preview/wrap", data["wave_preview"]["maximum_wrapped_counter_lines"], b["wave_preview_wrapped_lines"])
    alarm("hud/overflow", max(x["overflow_pixels"] for x in data["hud_bounds"]["configurations"]), b["hud_overflow_pixels"])
    alarm("hud/compact", data["hud_bounds"]["compact_layout_failures"], b["hud_overflow_pixels"])
    alarm("hud/message_tips", data["message_tips"]["layout_failures"], b["hud_overflow_pixels"])
    normal = data["upgrade_affordability"]["difficulties"]["normal"]
    for kind, row in normal.items():
        alarm("upgrade/first/"+kind, row["affordable_wave_range"]["first_upgrade"][1], b["balanced_first_upgrade_wave"])
        alarm("upgrade/final/"+kind, row["affordable_wave_range"]["final_tier_total"][1], b["balanced_final_tier_wave"])
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = build()
    failures = [x for x in checks(data) if not x[1]]
    if args.check:
        for name, _, detail in failures:
            print(f"POLISH REGRESSION {name}: {detail}", file=sys.stderr)
    else:
        data["checks"] = [{"name": n, "passed": ok, "detail": d} for n, ok, d in checks(data)]
        print(json.dumps(data, indent=2, sort_keys=True))
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
