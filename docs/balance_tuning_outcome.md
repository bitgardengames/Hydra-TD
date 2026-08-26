# Stat-only tower progression outcome

## August 2026 campaign pass

The full headless campaign matrix evaluates three deterministic variants for
each novice, competent, and hard policy: 405 complete campaign runs across all
15 maps and all three difficulties. Policy purchasing now preserves a mixed
defense by limiting repeated wave counters and buying an affordable Lancer (or
the cheapest remaining entry tower) rather than abandoning preparation when a
preferred specialist is too expensive.

To keep health values small and whole while making every enemy slightly sturdier,
standard enemy health is 17/43/14 for Grunts, Tanks, and Runners, and
57/41/41/53 for Bulwarks, Regenerators, Warcallers, and Summoners. Hard retains
its tighter life, reward, sell-refund, and boss contracts, and now applies a
whole 5x standard-enemy health contract; bosses retain their 1.2 multiplier.

The resulting required-policy matrix clears every map on the digestible campaign
settings: the novice policy won 45/45 Easy runs and the competent policy won
45/45 Normal runs. The deliberately punishing Hard stress policy lost 45/45
runs, exceeding the requested 44-failure threshold. Across all policies,
difficulties, maps, and three variants the headless pass executes 405 complete
campaign runs while exercising imperfect placement, mixed tower selection,
upgrades, active-ability timing, and real leaks. Hard is consequently treated as
an extreme challenge contract rather than another required campaign clear.

## Canonical assumptions

Canonical campaign, combat, replay-policy, economy, and polish fixtures model no
specialization and no inventory modules. The only progression inputs are the
four `UPGRADE_COST_MULTIPLIERS` in `world/towers.lua` and each tower's `upgrade`
`dmgMult`, `fireMult`, and `rangeAdd` values in `world/tower_defs.lua`.
Experimental branch/module coverage remains isolated in
`tools/balance/interaction_fixtures.py` and is not a release gate.

## Applied tuning

Upgrade prices are **0.5625x / 0.8125x / 1.125x / 1.50x** base cost. The maximum-level
stat multipliers and per-tier range additions are:

| Tower | Damage | Fire rate | Range/tier |
|---|---:|---:|---:|
| Slow | 1.70x | 1.35x | 0.16 tiles |
| Lancer | 2.65x | 1.18x | 0.08 tiles |
| Poison | 2.00x | 1.20x | 0.09 tiles |
| Cannon | 2.45x | 1.12x | 0.08 tiles |
| Shock | 2.10x | 1.20x | 0.11 tiles |
| Plasma | 2.15x | 1.25x | 0.09 tiles |

Runtime interpolation is linear from base to those maximum multipliers; range is
additive each tier. The fixture model mirrors that behavior rather than
exponentiating `fireMult`.

## Expansion comparison and acceptance

Each of the 24 upgrade purchases is priced against equal spending on another
base tower. Open legal placement compares marginal raw DPS and accepts ratios of
**0.24–1.15**. The constrained comparison accounts for the next legal tile's
coverage (72% useful uptime), switching and overkill (88% realization), retained
range, and bounded role utility (1.05–1.28), accepting **0.60–1.85**. The gate
also requires at least one open-board expansion win and at least one
placement-constrained upgrade win. This makes expansion preferable when good
coverage tiles remain, while upgrades become competitive when placement,
focus-fire, overkill, or specialist utility matters.

Polish alarms accept first-upgrade affordability through wave **2** and complete
stat-only towers through waves **2–8** on Hard. Current complete-tower probes span
waves **1–6** across maps; early Slow affordability is retained as an observed
edge rather than turned into a prescribed build.

## Reproduction

```sh
python3 tools/balance/check.py
python3 tools/balance/run_fixtures.py --write-docs
python3 tools/balance/polish_report.py --check
```
