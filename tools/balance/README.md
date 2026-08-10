# Balance fixture runner

The runner is dependency-free and deterministic. It uses a fixed `0.01` second
simulation tick and seed, reads the shipped Lua definitions, and emits stable
JSON (including damage and kills) to stdout.

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
