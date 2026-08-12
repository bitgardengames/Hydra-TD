# Simulated campaign balance baseline

This baseline was produced by running the deterministic combat, campaign pacing,
economy, challenge, interaction, and polish simulations together. Unlike earlier
single-coordinate recommendations, this pass applies a coordinated set of values
to the shipped game definitions.

## Applied outcome

### Towers and upgrades

The Slow, Poison, Cannon, Shock, and Plasma towers now fire at **1.20, 1.40,
0.70, 1.10, and 0.75 shots per second**, respectively. Lancer remains at 2.20
shots per second as the single-target baseline. The modest specialist throughput
increase keeps each counter useful against the correspondingly tougher enemy
roster without collapsing the specialist roles into generic damage choices.

Upgrade prices now use **1.30x, 1.70x, 2.20x, and 2.80x** base tower cost. This
makes the first specialization a slightly more deliberate purchase while reducing
the old late-upgrade wall (previously 3.20x at the final tier). The simulated
median first-upgrade purchase moves from wave 2 to wave 3.

### Enemies, income, and waves

Tank, Bulwark, Regenerator, Shieldbearer, Warcaller, and Summoner base HP are now
**41, 56, 38, 37, 37, and 50**. Boss HP is now **330 / 290 / 330 / 360** for the
base, summoner, displacement, and suppression encounters. Rewards remain tied to
the established durability bands, avoiding income inflation from the HP pass.

Flawless completion income is now **$2 on Easy and Normal** in ordinary rounding
cases and **$1 on Hard**, with existing boss and milestone modifiers still
applying. Kill rewards remain the primary economy, but clean play now creates a
visible cushion without moving the economy fixtures outside their purchasing
bands.

The long-form Outer Loop, Terrace, and High Ridge openings each use **17 rather
than 18 Grunts**. This removes one low-information opening target after the enemy
durability increase while retaining every map's authored opening-pressure,
duration, recovery, and peak-density identity.

## Aggregate result

| Metric | Previous baseline | Tuned baseline | Authored target |
|:--|--:|--:|:--|
| Required / affordable DPS | 6,412 bp | 6,500 bp | 4,200–9,000 bp |
| Wave-income coverage | 4,532 bp | 4,425 bp | 3,500–8,000 bp |
| Threat per reward dollar | 5 | 5 | 3–5 |
| Specialist role performance | 10,000 bp | 10,000 bp | 9,000–10,000 bp |
| Leak allowance | 2,467 bp | 2,578 bp | 500–2,200 bp |
| First-upgrade timing | wave 2 | wave 3 | waves 2–5 |
| Wave-to-wave growth | 12,000 bp | 12,026 bp | 10,100–13,500 bp |

Leak allowance remains outside the aspirational target. Reducing it independently
would weaken enemy durability or erase specialist distinctions, so it remains an
explicit playtest focus rather than being hidden by loosening fixture bands. All
hard campaign, affordability, role, economy, interaction, pacing, and polish
constraints pass with the applied values.

## Reproduction

```sh
python3 tools/balance/check.py
python3 - <<'PY'
import json, sys
sys.path.insert(0, "tools/balance")
import challenge_fixtures, recommend
manifest = json.load(open("tools/balance/tuning_parameters.json"))["parameters"]
files = sorted({item["source_file"] for item in manifest})
texts = {name: open(name).read() for name in files}
print(recommend.metrics(challenge_fixtures.build_report(), texts, manifest))
PY
```

Regenerate checked-in evidence after an accepted value change:

```sh
python3 tools/balance/run_fixtures.py --write-docs
python3 tools/balance/challenge_fixtures.py --write-docs
python3 tools/balance/interaction_fixtures.py --write
```
