#!/usr/bin/env python3
"""Report and guard the authored campaign's spawn-schedule pacing."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "systems/campaign_wave_defs.lua"
WINDOW_SECONDS = 5.0
GROUP = re.compile(
    r'g\("(?P<kind>[a-z]+)",\s*(?P<count>\d+),\s*'
    r'(?P<spacing>[0-9.]+),\s*(?P<delay>[0-9.]+)\)'
)


def table_block(text: str, declaration: str) -> str:
    start = text.index(declaration) + len(declaration)
    depth = 1
    for pos in range(start, len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return text[start:pos]
    raise ValueError(f"unterminated table after {declaration!r}")


def named_blocks(block: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for match in re.finditer(r"^\s*([a-z][a-z0-9_]*)\s*=\s*\{", block, re.M):
        name, start, depth = match.group(1), match.end(), 1
        for pos in range(start, len(block)):
            depth += (block[pos] == "{") - (block[pos] == "}")
            if depth == 0:
                found[name] = block[start:pos]
                break
    return found


def parse_waves(text: str) -> dict[str, list[list[dict]]]:
    maps = named_blocks(table_block(text, "local wavesByMapId = {"))
    result = {}
    for map_id, block in maps.items():
        waves = []
        for wave in range(1, 11):
            match = re.search(rf"\[{wave}\]\s*=\s*\{{([^\n]+)\}}", block)
            if not match:
                raise ValueError(f"{map_id} wave {wave} is missing")
            groups = []
            for group in GROUP.finditer(match.group(1)):
                groups.append({
                    "kind": group["kind"], "count": int(group["count"]),
                    "spacing": float(group["spacing"]),
                    "delay": float(group["delay"]),
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


def parse_targets(text: str) -> dict[str, dict]:
    blocks = named_blocks(table_block(text, "local pacingTargetsByMapId = {"))
    targets = {}
    for map_id, block in blocks.items():
        scalar = lambda name: float(re.search(rf"{name}\s*=\s*([0-9.]+)", block).group(1))
        pair = lambda name: [float(x) for x in re.search(
            rf"{name}\s*=\s*\{{\s*([0-9.]+),\s*([0-9.]+)\s*\}}", block).groups()]
        targets[map_id] = {
            "openingPressure": int(scalar("openingPressure")),
            "peakSimultaneous": int(scalar("peakSimultaneous")),
            "totalWaveDuration": pair("totalWaveDuration"),
            "downtimeBetweenGroups": pair("downtimeBetweenGroups"),
        }
    return targets


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail when measured pacing misses an authored target")
    args = parser.parse_args()
    text = SOURCE.read_text()
    measured = {map_id: [wave_metrics(w) for w in waves]
                for map_id, waves in parse_waves(text).items()}
    summaries = {map_id: summarize(waves) for map_id, waves in measured.items()}
    targets = parse_targets(text)
    mismatches = {map_id: {"target": targets.get(map_id), "measured": summary}
                  for map_id, summary in summaries.items() if targets.get(map_id) != summary}
    if args.check:
        for map_id, mismatch in mismatches.items():
            print(f"PACING REGRESSION {map_id}: {mismatch}", file=sys.stderr)
    else:
        print(json.dumps({"engagementWindowSeconds": WINDOW_SECONDS,
                          "maps": measured, "summaries": summaries,
                          "targets": targets, "mismatches": mismatches}, indent=2))
    return 1 if mismatches else 0


if __name__ == "__main__":
    raise SystemExit(main())
