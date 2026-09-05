#!/usr/bin/env python3
"""Report the authored campaign's spawn-schedule pacing."""

from __future__ import annotations

import json
import re
from pathlib import Path

from lua_source import named_entries, table_body

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "systems/campaign_wave_defs.lua"
WINDOW_SECONDS = 5.0
GROUP = re.compile(
    r'g\("(?P<kind>[a-z]+)",\s*(?P<count>\d+),\s*'
    r'(?P<spacing>[0-9.]+)(?:,\s*(?P<delay>[0-9.]+))?'
)


def parse_waves(text: str) -> dict[str, list[list[dict]]]:
    declaration = "wavesByMapId"
    maps = named_entries(table_body(text, declaration, SOURCE), declaration, SOURCE)
    result = {}
    for map_id, block in maps.items():
        waves = []
        for wave in range(1, 21):
            match = re.search(rf"\[{wave}\]\s*=\s*\{{([^\n]+)\}}", block)
            if not match:
                raise ValueError(f"{map_id} wave {wave} is missing")
            groups = []
            for group in GROUP.finditer(match.group(1)):
                groups.append({
                    "kind": group["kind"], "count": int(group["count"]),
                    "spacing": float(group["spacing"]),
                    "delay": float(group["delay"] or 0),
                })
            if not groups:
                raise ValueError(f"{map_id} wave {wave} has no groups")
            waves.append(groups)
        result[map_id] = waves
    return result


def wave_metrics(groups: list[dict]) -> dict:
    time = 0.0
    spawns = []
    recoveries = []
    for index, group in enumerate(groups):
        time += group["delay"]
        if index:
            recoveries.append(group["delay"])
        for enemy in range(group["count"]):
            spawns.append(round(time + enemy * group["spacing"], 6))
        time = spawns[-1]
    peak = 0
    left = 0
    for right, spawn in enumerate(spawns):
        while spawns[left] < spawn - WINDOW_SECONDS:
            left += 1
        peak = max(peak, right - left + 1)
    return {
        "openingPressure": sum(t <= WINDOW_SECONDS for t in spawns),
        "peakSimultaneous": peak,
        "totalWaveDuration": round(spawns[-1], 2),
        "downtimeBetweenGroups": recoveries,
        "totalEnemies": len(spawns),
    }


def summarize(waves: list[dict]) -> dict:
    recoveries = [gap for wave in waves for gap in wave["downtimeBetweenGroups"]]
    durations = [wave["totalWaveDuration"] for wave in waves]
    return {
        "openingPressure": max(wave["openingPressure"] for wave in waves),
        "peakSimultaneous": max(wave["peakSimultaneous"] for wave in waves),
        "totalWaveDuration": [min(durations), max(durations)],
        "downtimeBetweenGroups": [min(recoveries), max(recoveries)],
    }


def main() -> int:
    text = SOURCE.read_text()
    measured = {map_id: [wave_metrics(w) for w in waves]
                for map_id, waves in parse_waves(text).items()}
    summaries = {map_id: summarize(waves) for map_id, waves in measured.items()}
    print(json.dumps({"engagementWindowSeconds": WINDOW_SECONDS,
                      "maps": measured, "summaries": summaries}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
