# Balance fixture runner

The runner is dependency-free and deterministic. It uses a fixed `0.01` second
simulation tick and seed, reads the shipped Lua definitions, and emits stable
JSON (including damage and kills) to stdout. Combat role and upgrade-timing
acceptance is anchored to Hard difficulty, where the intended challenge lives.

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

The aggregate report includes a strategy-family audit for every map, wave, and
difficulty. Run its full machine-readable report directly with:

```sh
python3 tools/balance/strategy_analysis.py
python3 tools/balance/strategy_analysis.py --check
```

The audit deterministically samples affordable plans across tower-role mixes,
upgrade branches, placement regions, and ability loadouts. Purchase-order-only
differences are canonicalized away. Each viable family is perturbed by moving a
tower, delaying an upgrade or ability, substituting a tower, and removing five
percent of available income. The report gives the independently viable and
robust family counts, margin, and fraction of perturbations survived. Thresholds
live in `strategy_bands.json`; an encounter may waive them only by listing its
full `difficulty/map/wave_N` id in `puzzles` as an explicit design decision.

These are conservative static proxies for strategic breathing room, not claims
that an AI played the map. A passing count can still hide awkward targeting,
unfun pacing, inaccessible execution, or families that players will not discover;
a failure can reveal either brittle tuning or an intentionally puzzle-like idea.
Use the detailed families to choose human playtest cases, then review placement,
timing, clarity, enjoyment, and player-observed success. The metrics inform that
review and must never replace it.

## Reviewed tuning proposals

`recommend.py` is a deterministic, standard-library-only constrained optimizer.
It reads the report returned by `challenge_fixtures.build_report()` and scores
every map and difficulty against a **named authored target** in
`target_profiles.json`. Targets are design intent and are deliberately not
inferred from today's fixtures. The only values it can propose are the explicit
entries in `tuning_parameters.json`; each entry names its Lua source/table/key,
range, step, and per-pass change cap.

Generate and inspect a proposal (the JSON is stable for the same checkout):

```sh
python3 tools/balance/recommend.py --recommend \
  --profile intended_challenge --output balance-recommendation.json
git diff --no-index /dev/null balance-recommendation.json
```

The report includes old/new values, reasons, affected objective metrics, and a
confidence label. It starts with `"reviewed": false`. A human must inspect the
gameplay intent and source locator, then deliberately change that field to
`true`. Source and manifest hashes prevent a stale approval from being reused.
Preview the exact edit without touching the checkout:

```sh
python3 tools/balance/recommend.py --patch balance-recommendation.json
```

Only after review, apply the artifact:

```sh
python3 tools/balance/recommend.py --apply balance-recommendation.json
```

Apply validates the reviewed values against the allow-list, changes only those
keys, and runs `python3 tools/balance/check.py`. On any failed combat, pacing,
economy, challenge, interaction, or polish gate it restores every touched file
and exits unsuccessfully. Candidate search also rejects the combat-role hard
constraints: control, baseline single-target, burst, and chain specialists may
not collapse into interchangeable raw-DPS choices.

These recommendations are **proposals, not proof of fun or fairness**. Static
threat windows, affordability, role coverage, leak allowance, and curve growth
are useful review evidence, but cannot represent path placement, player
learning, accessibility, or enjoyment. Playtesting and human review remain
required even when every numerical gate passes.

The aggregate command also runs the campaign challenge gate. It parses shipped
tower output, enemy durability/mechanics, fixed campaign compositions, and both
difficulty sources, then audits every map/wave/difficulty in integer fixed-point
units:

```sh
python3 tools/balance/challenge_fixtures.py --check
python3 tools/balance/challenge_fixtures.py --write-docs
```

The generated `docs/challenge_fixtures.md` first verifies each enemy's whole-number
reward against its mechanic-weighted durability. Its wave table then records enemy
count and type, effective and peak five-second durability, income, threat per
income dollar, income-funded damage, pre-wave purchasing power, the money reserved
for composition counters, an integer-optimized affordable loadout, the
required/affordable DPS ratio, and the share of required damage funded by that
wave's income. Difficulty- and wave-specific ratio envelopes in
`challenge_bands.json` retain room for specialist introductions while giving the
shipped range only about ten percent integer headroom. An independent
income-coverage envelope couples each wave's payout to its peak damage requirement,
rather than allowing cumulative starting money to hide a reward or composition
drift. This makes tower output,
enemy count and composition, kill income, and difficulty economy move as one
curve without turning the fixture into a prescribed player build.

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

## Non-rendered polish metrics

Refinement budgets that can be calculated from authored data and declarative UI
geometry have their own dependency-free report:

```sh
python3 tools/balance/polish_report.py
python3 tools/balance/polish_report.py --check
```

The report covers preparation/recovery cadence, authored-wave pressure, event
rates, ability uptime and overlaps, preview wrapping, HUD bounds, and upgrade
timing. It explicitly exercises 1280×720 at the default font size, six damage-meter
rows, six ability buttons, and the largest campaign preview. The check uses the
broad alarm bands documented in `docs/polish_fixtures.md`.
