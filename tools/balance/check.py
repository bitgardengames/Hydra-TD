#!/usr/bin/env python3
"""Dependency-free aggregate balance gate."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GATES = (("combat", "run_fixtures.py"),
         ("economy", "economy_fixtures.py"),
         ("campaign challenge", "challenge_fixtures.py"),
         ("strategy diversity + robustness", "strategy_analysis.py"),
         ("headless campaign policies", "campaign_simulator.py"),
         ("polish metrics", "polish_report.py"))
failed = []
for name, script in GATES:
    result = subprocess.run([sys.executable, str(ROOT / "tools/balance" / script), "--check"],
                            cwd=ROOT, check=False)
    print(f'{"PASS" if result.returncode == 0 else "FAIL"} {name}')
    if result.returncode:
        failed.append(name)
    if script == "strategy_analysis.py" and not result.returncode:
        subprocess.run([sys.executable, str(ROOT / "tools/balance" / script), "--summary"],
                       cwd=ROOT, check=True)
raise SystemExit(bool(failed))
