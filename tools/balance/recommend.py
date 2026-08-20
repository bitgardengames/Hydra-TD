#!/usr/bin/env python3
"""Deterministic, dependency-free balance proposal and review tool.

This deliberately treats optimization as constrained search, not as an automatic
truth machine.  Candidate reports are produced by the same parser/calculations as
``challenge_fixtures`` and every accepted change retains the authored tower-role
invariants below.
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "tools/balance"
sys.path.insert(0, str(HERE))
import challenge_fixtures  # noqa: E402 (local, dependency-free fixture)

MANIFEST = HERE / "tuning_parameters.json"
PROFILES = HERE / "target_profiles.json"
METRIC_NAMES = ("required_to_affordable_dps_bp", "wave_income_coverage_bp",
                "threat_per_reward_dollar", "specialist_role_performance_bp",
                "leak_allowance_bp", "upgrade_purchase_timing_wave",
                "wave_to_wave_difficulty_growth_bp")


def canonical(value: object) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry_block(text: str, entry: str) -> tuple[int, int]:
    match = re.search(rf"^\s*{re.escape(entry)}\s*=\s*\{{", text, re.M)
    if not match:
        raise ValueError(f"Lua entry not found: {entry}")
    depth = 1
    for pos in range(match.end(), len(text)):
        depth += (text[pos] == "{") - (text[pos] == "}")
        if depth == 0:
            return match.end(), pos
    raise ValueError(f"unterminated Lua entry: {entry}")


def value_span(text: str, parameter: dict) -> tuple[int, int, str]:
    table, key = parameter["lua_table"], parameter["lua_key"]
    if table == "UPGRADE_COST_MULTIPLIERS":
        match = re.search(r"local UPGRADE_COST_MULTIPLIERS\s*=\s*\{([^}]*)\}", text)
        values = list(re.finditer(r"[0-9]+(?:\.[0-9]+)?", match.group(1))) if match else []
        index = int(parameter["entry"]) - 1
        if index >= len(values):
            raise ValueError(f"upgrade multiplier not found: {parameter['id']}")
        item = values[index]
        return match.start(1) + item.start(), match.start(1) + item.end(), item.group()
    if table == "wavesByMapId":
        map_id, wave, group = parameter["entry"].split(".")
        root = text.index("local wavesByMapId")
        relative_start, relative_end = entry_block(text[root:], map_id)
        start, end = root + relative_start, root + relative_end
        body = text[start:end]
        row = re.search(rf"^\s*\[{wave}\]\s*=\s*\{{([^\n]+)", body, re.M)
        # Start-immediately groups omit the optional delay argument.
        calls = list(re.finditer(r'g\("[a-z_]+",\s*([0-9.]+),\s*([0-9.]+)(?:,\s*([0-9.]+))?', row.group(1))) if row else []
        call = calls[int(group) - 1]
        capture = 1 if key == "count" else 2
        return start + row.start(1) + call.start(capture), start + row.start(1) + call.end(capture), call.group(capture)
    start, end = entry_block(text, parameter["entry"])
    match = re.search(rf"\b{re.escape(key)}\s*=\s*([0-9]+(?:\.[0-9]+)?)", text[start:end])
    if not match:
        raise ValueError(f"key not found: {parameter['id']}")
    return start + match.start(1), start + match.end(1), match.group(1)


def display(value: float, parameter: dict) -> int | float:
    step = parameter["step"]
    if isinstance(step, int) or float(step).is_integer():
        return int(round(value))
    decimals = len(str(step).partition(".")[2])
    return round(value, decimals)


def replace_value(text: str, parameter: dict, value: float) -> str:
    start, end, _ = value_span(text, parameter)
    return text[:start] + str(display(value, parameter)) + text[end:]


def current_value(parameter: dict, texts: dict[str, str]) -> int | float:
    _, _, raw = value_span(texts[parameter["source_file"]], parameter)
    return display(float(raw), parameter)


def metrics(report: dict, texts: dict[str, str], manifest: list[dict]) -> dict[str, int]:
    rows = [row for maps in report["difficulties"].values() for waves in maps.values() for row in waves]
    ratios = sorted(row["required_to_affordable_bp"] for row in rows)
    incomes = sorted(row["wave_income_to_required_bp"] for row in rows)
    threat = sorted(row["threat_per_dollar"] for key, row in report["enemy_archetypes"].items()
                    if not key.startswith("boss_"))
    coverage = sum(len(row["specialist_coverage"]) for row in rows)
    required = sum(len(row["required_specialists"]) for row in rows)
    leaks = sum(row["required_to_affordable_bp"] > 10_000 for row in rows)
    growth = []
    for maps in report["difficulties"].values():
        for waves in maps.values():
            growth.extend(round(b["required_damage"] * 10_000 / max(1, a["required_damage"]))
                          for a, b in zip(waves, waves[1:]))

    # Upgrade timing is a design affordability proxy: median wave at which
    # cumulative full-clear income buys a representative first upgrade.
    tower_costs = [current_value(p, texts) for p in manifest if p["id"].startswith("tower.") and p["lua_key"] == "cost"]
    multiplier = current_value(next(p for p in manifest if p["id"] == "upgrade_cost_multiplier.1"), texts)
    purchase_waves = []
    target = sorted(tower_costs)[len(tower_costs) // 2] * (1 + multiplier)
    for maps in report["difficulties"].values():
        for waves in maps.values():
            purchase_waves.append(next((r["wave"] for r in waves if r["purchasing_power_before_wave"] >= target), 10))
    median = lambda values: int(sorted(values)[len(values) // 2])
    return {
        "required_to_affordable_dps_bp": median(ratios),
        "wave_income_coverage_bp": median(incomes),
        "threat_per_reward_dollar": median(threat),
        "specialist_role_performance_bp": round(coverage * 10_000 / max(1, required)),
        "leak_allowance_bp": round(leaks * 10_000 / len(rows)),
        "upgrade_purchase_timing_wave": median(purchase_waves),
        "wave_to_wave_difficulty_growth_bp": median(growth),
    }


def score(values: dict, objectives: dict) -> int:
    total = 0
    for name, target in objectives.items():
        value, low, high = values[name], target["minimum"], target["maximum"]
        distance = low - value if value < low else value - high if value > high else 0
        width = max(1, high - low)
        total += target["weight"] * distance * distance * 1_000_000 // (width * width)
    return total


def role_constraints(report: dict, texts: dict[str, str], manifest: list[dict]) -> list[str]:
    towers, *_ = challenge_fixtures.definitions()
    failures = []
    if not towers["lancer"]["sustained_damage"] * towers["slow"]["cost"] > towers["slow"]["sustained_damage"] * towers["lancer"]["cost"]:
        failures.append("lancer must remain more cost-efficient than control-focused slow")
    if not towers["cannon"]["sustained_damage"] > towers["slow"]["sustained_damage"]:
        failures.append("cannon burst must remain above slow direct damage")
    if not towers["shock"]["sustained_damage"] < towers["lancer"]["sustained_damage"]:
        failures.append("shock raw single-target damage must remain below lancer")
    if metrics(report, texts, manifest)["specialist_role_performance_bp"] != 10_000:
        failures.append("every required combat counter must remain affordable")
    return failures


class Sources:
    """Transactionally expose candidate Lua source to challenge_fixtures."""
    def __init__(self, texts: dict[str, str]): self.texts = texts
    def evaluate(self) -> dict:
        originals = {name: (ROOT / name).read_text() for name in self.texts}
        try:
            for name, value in self.texts.items(): (ROOT / name).write_text(value)
            return challenge_fixtures.build_report()
        finally:
            for name, value in originals.items(): (ROOT / name).write_text(value)


def candidate_pool(parameters: list[dict]) -> list[dict]:
    fixed = [p for p in parameters if not p["id"].startswith("campaign.")]
    waves = [p for p in parameters if p["id"].startswith("campaign.")]
    # Search a deterministic, evenly distributed campaign frontier. This avoids
    # favoring early maps while keeping a review command comfortably interactive.
    stride = max(1, len(waves) // 24)
    return fixed + waves[::stride]


def recommend(profile_name: str) -> dict:
    manifest_doc = json.loads(MANIFEST.read_text())
    profiles = json.loads(PROFILES.read_text())
    if profile_name not in profiles["profiles"]:
        raise ValueError(f"unknown profile {profile_name!r}")
    parameters = manifest_doc["parameters"]
    files = sorted({p["source_file"] for p in parameters})
    base_texts = {name: (ROOT / name).read_text() for name in files}
    base_report = challenge_fixtures.build_report()
    objectives = profiles["profiles"][profile_name]["objectives"]
    before = metrics(base_report, base_texts, parameters)
    base_score = score(before, objectives)
    evaluated = []
    pool = candidate_pool(parameters)
    for parameter in pool:
        old = float(current_value(parameter, base_texts))
        cap = old * parameter["maximum_percentage_change"] / 100
        # The profile violations determine a stable descent direction. A later
        # pass reverses naturally if a metric crosses its target envelope.
        ident = parameter["id"]
        if ident.startswith("upgrade_cost_multiplier"):
            direction = 1 if before["upgrade_purchase_timing_wave"] < objectives["upgrade_purchase_timing_wave"]["minimum"] else -1
        elif ident.endswith(".spacing"):
            direction = 1 if before["leak_allowance_bp"] > objectives["leak_allowance_bp"]["maximum"] else -1
        elif ident.endswith(".count") or ident.endswith(".hp") or ident.endswith(".cost"):
            direction = -1 if before["leak_allowance_bp"] > objectives["leak_allowance_bp"]["maximum"] else 1
        else:  # damage, fire rate, and rewards all increase affordable output
            direction = 1 if before["leak_allowance_bp"] > objectives["leak_allowance_bp"]["maximum"] else -1
        for direction in (direction,):
            proposed = display(old + direction * parameter["step"], parameter)
            if not parameter["minimum"] <= proposed <= parameter["maximum"] or abs(proposed - old) > cap + 1e-9:
                continue
            texts = dict(base_texts)
            texts[parameter["source_file"]] = replace_value(texts[parameter["source_file"]], parameter, proposed)
            report = Sources(texts).evaluate()
            after = metrics(report, texts, parameters)
            failures = challenge_fixtures.checks(report) + role_constraints(report, texts, parameters)
            change_penalty = 500 + round(abs(proposed - old) / max(1, abs(old)) * 10_000)
            candidate_score = score(after, objectives) + change_penalty
            if not failures and candidate_score < base_score:
                affected = [name for name in METRIC_NAMES if before[name] != after[name]]
                evaluated.append((candidate_score, parameter, proposed, after, affected))
    evaluated.sort(key=lambda row: (row[0], row[1]["id"], row[2]))
    # One proposal is intentionally conservative: reviewers can apply it, rerun,
    # and obtain the next coordinate rather than accepting a coupled opaque jump.
    changes = []
    if evaluated:
        candidate_score, parameter, proposed, after, affected = evaluated[0]
        improvement = base_score - candidate_score
        reasons = [f"moves {name} from {before[name]} toward {objectives[name]['minimum']}..{objectives[name]['maximum']}"
                   for name in affected if not objectives[name]["minimum"] <= before[name] <= objectives[name]["maximum"]]
        changes.append({"parameter": parameter["id"], "source_file": parameter["source_file"],
                        "lua_table": parameter["lua_table"], "lua_key": parameter["lua_key"],
                        "current_value": current_value(parameter, base_texts), "proposed_value": proposed,
                        "reason": "; ".join(reasons) or "reduces the weighted target-profile penalty",
                        "affected_metrics": {name: {"current": before[name], "proposed": after[name]} for name in affected},
                        "confidence": "high" if improvement * 4 > max(1, base_score) else "medium"})
    return {"format_version": 1, "mode": "recommend", "profile": profile_name,
            "reviewed": False, "manifest_sha256": digest(MANIFEST),
            "source_sha256": {name: hashlib.sha256(base_texts[name].encode()).hexdigest() for name in files},
            "current_metrics": before, "target_objectives": objectives,
            "current_penalty": base_score, "candidates_evaluated": len(pool),
            "recommendations": changes}


def reviewed_changes(artifact_path: Path) -> tuple[dict, list[dict], dict[str, str]]:
    artifact = json.loads(artifact_path.read_text())
    if artifact.get("reviewed") is not True:
        raise ValueError("artifact must be explicitly marked reviewed: true")
    if artifact.get("manifest_sha256") != digest(MANIFEST):
        raise ValueError("artifact manifest hash does not match the current allow-list")
    manifest = json.loads(MANIFEST.read_text())["parameters"]
    by_id = {p["id"]: p for p in manifest}
    texts = {name: (ROOT / name).read_text() for name in {p["source_file"] for p in manifest}}
    for name, expected in artifact.get("source_sha256", {}).items():
        if hashlib.sha256(texts[name].encode()).hexdigest() != expected:
            raise ValueError(f"source changed since review: {name}")
    selected = []
    for change in artifact.get("recommendations", []):
        parameter = by_id.get(change.get("parameter"))
        if not parameter:
            raise ValueError(f"parameter is not allow-listed: {change.get('parameter')}")
        current, proposed = current_value(parameter, texts), change["proposed_value"]
        cap = float(current) * parameter["maximum_percentage_change"] / 100
        steps = abs((float(proposed) - float(current)) / parameter["step"])
        if current != change["current_value"] or not parameter["minimum"] <= proposed <= parameter["maximum"] or abs(steps - round(steps)) > 1e-7 or abs(proposed-current) > cap + 1e-9:
            raise ValueError(f"reviewed value violates manifest constraints: {parameter['id']}")
        texts[parameter["source_file"]] = replace_value(texts[parameter["source_file"]], parameter, proposed)
        selected.append(parameter)
    return artifact, selected, texts


def patch_text(artifact_path: Path) -> tuple[str, dict[str, str]]:
    _, selected, texts = reviewed_changes(artifact_path)
    output = []
    for name in sorted({p["source_file"] for p in selected}):
        old = (ROOT / name).read_text().splitlines(keepends=True)
        new = texts[name].splitlines(keepends=True)
        output.extend(difflib.unified_diff(old, new, fromfile=f"a/{name}", tofile=f"b/{name}"))
    return "".join(output), texts


def apply(artifact_path: Path) -> None:
    diff, texts = patch_text(artifact_path)
    if not diff:
        return
    originals = {name: (ROOT / name).read_text() for name in texts}
    try:
        for name, value in texts.items(): (ROOT / name).write_text(value)
        result = subprocess.run([sys.executable, str(HERE / "check.py")], cwd=ROOT)
        if result.returncode:
            raise RuntimeError("balance gate rejected the reviewed candidate")
    except BaseException:
        for name, value in originals.items(): (ROOT / name).write_text(value)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--recommend", action="store_true")
    modes.add_argument("--patch", metavar="REVIEWED_ARTIFACT", type=Path)
    modes.add_argument("--apply", metavar="REVIEWED_ARTIFACT", type=Path)
    parser.add_argument("--profile")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.recommend:
            profiles = json.loads(PROFILES.read_text())
            result = canonical(recommend(args.profile or profiles["default_profile"]))
            if args.output: args.output.write_text(result)
            else: sys.stdout.write(result)
        elif args.patch:
            sys.stdout.write(patch_text(args.patch)[0])
        else:
            apply(args.apply)
    except (KeyError, ValueError, RuntimeError, OSError) as exc:
        print(f"recommend.py: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
