#!/usr/bin/env python3
"""Dependency-free aggregate balance gate."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GATES = (("combat", "run_fixtures.py"), ("pacing", "campaign_pacing_report.py"),
         ("economy", "economy_fixtures.py"),
         ("ability + interactions", "interaction_fixtures.py"))
failed = []
for name, script in GATES:
    result = subprocess.run([sys.executable, str(ROOT / "tools/balance" / script), "--check"],
                            cwd=ROOT, check=False)
    print(f'{"PASS" if result.returncode == 0 else "FAIL"} {name}')
    if result.returncode:
        failed.append(name)
raise SystemExit(bool(failed))
