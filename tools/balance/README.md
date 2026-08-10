# Balance fixture runner

The runner is dependency-free and deterministic. It uses a fixed `0.01` second
simulation tick and seed, reads the shipped Lua definitions, and emits stable
JSON (including damage and kills) to stdout.

The tick is read from `core/simulation_clock.lua`, the same source used by the
runtime. The gate also drives a tick-authored encounter at 30, 60, and 144
rendered FPS at 1x, 2x, and 4x speed. Kills, leaks, income, wave completion, and
the completion tick must match exactly; cooldown completion may differ by at
most one simulation tick (0.01 seconds). Runtime catch-up is capped at 16 ticks
per rendered frame. Any accumulated time above that 0.16-second budget is
discarded, not carried forward, so a long stall cannot lock the client into an
unbounded backlog.

Regenerate the documented tables:

```sh
python3 tools/balance/run_fixtures.py --write-docs
```

Only report role/efficiency regressions (silent success, non-zero on failure):

```sh
python3 tools/balance/run_fixtures.py --check
```

Run without flags to obtain the complete machine-readable capture. The
`definition_sha256` field fingerprints the tower, enemy, branch, module, and
difficulty sources used by the capture.

## Aggregate gate

Run every combat, campaign pacing, economy, ability, and interaction gate with
one dependency-free command:

```sh
python3 tools/balance/check.py
```

`interaction_fixtures.json` records every active ability variant and branch
mapping, representative module combat formations, targeting expectations, and
the boss templates' dynamically summoned adds. It includes total damage,
coverage, leaks, proc counts, and cost efficiency. Radius-boundary, cooldown,
2x/4x speed, and overlapping-effect invariants use broad tuning tolerances.

The capture fingerprints tower, enemy, branch, module, ability, difficulty,
campaign-wave, runtime-wave, and targeting definitions. Any edit to those files
fails the gate until the fixtures are generated and reviewed:

```sh
python3 tools/balance/interaction_fixtures.py --write
git diff -- tools/balance/interaction_fixtures.json
python3 tools/balance/check.py
```

## Campaign pacing

Campaign encounters have a separate, dependency-free schedule audit:

```sh
python3 tools/balance/campaign_pacing_report.py
python3 tools/balance/campaign_pacing_report.py --check
```

The report reconstructs the sequential group spawner exactly: a group's delay
is downtime after the preceding group, while spacing separates enemies inside a
group. “Opening pressure” is the number spawned in the first five seconds and
“peak simultaneous” is the largest number spawned in any five-second engagement
window (a deterministic pressure proxy, rather than a path-length-dependent live
enemy count). It also emits every wave's total enemy count, spawn duration, and
recovery gaps. `--check` compares each map's measured summary with the targets in
`systems/campaign_wave_defs.lua`, exposing accidental count, duration, or density
creep as a pacing regression.

## Campaign economy

The economy fixture parses every authored campaign group, enemy reward, and
difficulty directly from Lua and models three representative (not prescriptive)
play styles:

```sh
python3 tools/balance/economy_fixtures.py
python3 tools/balance/economy_fixtures.py --check
```

Normal output is stable JSON with per-map, per-wave kill, flawless, early-call,
and cumulative income plus affordability anchors and sell losses. `--check` is
silent on success and compares only the broad bands in `economy_bands.json`.
