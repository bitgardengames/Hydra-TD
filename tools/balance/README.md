# Balance fixture runner

The runner is dependency-free and deterministic. It uses a fixed `0.01` second
simulation tick and seed, reads the shipped Lua definitions, and emits stable
JSON (including damage and kills) to stdout. Combat role and upgrade-timing
acceptance is anchored to Hard difficulty, where the intended challenge lives.

The tick is read from `core/simulation_clock.lua`, the same source used by the
runtime. The gate also drives a tick-authored encounter at 30, 60, and 144
rendered FPS at 1x and 2x speed. Kills, leaks, income, wave completion, and
the completion tick must match exactly; cooldown completion may differ by at
most one simulation tick (0.01 seconds). Runtime catch-up is capped at 8 ticks
per rendered frame. Any accumulated time above that 0.08-second budget is
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

## Aggregate gate (mandatory stat-only release coverage)

The aggregate release gate targets normal campaign/replay rules: stat-only tower
upgrades with experimental modules disabled. Module combination coverage is not
part of this command and cannot be used as evidence for a mandatory balance row.


Run every mandatory combat, campaign pacing, economy, ability, and polish gate with
one dependency-free command:

```sh
python3 tools/balance/check.py
```

Module and specialization combinations have a separate experimental check. Run
and review it only for an explicitly enabled internal module playtest:

```sh
python3 tools/balance/interaction_fixtures.py --check
python3 tools/balance/interaction_fixtures.py --write
```

Its module results are experimental QA, not a release blocker. The mandatory
aggregate report still includes stat-only ability and campaign coverage through
its other fixtures.

The aggregate report includes a strategy-family audit for every map, wave, and
difficulty. Run its full machine-readable report directly with:

```sh
python3 tools/balance/strategy_analysis.py
python3 tools/balance/strategy_analysis.py --check
```

The audit deterministically samples affordable plans across tower-role mixes,
upgrade timing, placement regions, and ability loadouts. Purchase-order-only
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

`interaction_fixtures.json` is the separate cross-system interaction report. It
records ability geometry, targeting expectations, and the boss templates'
dynamically summoned adds. Radius-boundary, cooldown, 2x speed and
overlapping-effect invariants use broad tuning tolerances.

This capture fingerprints tower, enemy, module, ability, difficulty,
campaign-wave, runtime-wave, and targeting definitions. Any edit to those files
fails the gate until the fixtures are generated and reviewed:

```sh
python3 tools/balance/interaction_fixtures.py --write
git diff -- tools/balance/interaction_fixtures.json
python3 tools/balance/interaction_fixtures.py --check
```

Do not add this command back to `tools/balance/check.py`; module combinations are
kept outside mandatory stat-only release coverage.

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

## Headless campaign policies

Run the deterministic campaign player directly, or enforce its authored bands:

```sh
python3 tools/balance/campaign_simulator.py
python3 tools/balance/campaign_simulator.py --check
python3 tools/balance/campaign_simulator.py --summary
```

The simulator runs novice, competent, and hard policies across every campaign
map and difficulty with three deterministic variants.  Unlike the aggregate
challenge estimates, it advances individual enemies along authored route lengths
on fixed ticks and executes acquisition, cooldowns, attacks, splash/chain hits,
armor, regeneration, poison, slows, kills, leaks, purchases, upgrades, sales,
and active abilities.  Each policy has an explicit, constrained placement search,
counter-knowledge probability, purchase lookahead, upgrade preference, timing
accuracy, retry allowance, and search budget.  Thus weaker policies choose bad
positions, miss counters, mistime abilities, and spend shortsightedly; their
damage and money are not silently multiplied by a handicap.

Stable JSON records each variant's victory, lives, failed wave, unused money,
tower composition, rebuilds, ability uses/utilization, and the victory-rate margin
between the strongest and weakest policy. `campaign_acceptance_bands.json` owns
the reviewed expectations: novice for Easy, competent for Normal, and a maximum
success rate for the deliberately punishing Hard stress policy, while allowing
several builds and deterministic retries.  The report also
fingerprints every runtime definition or implementation file it consumes/mirrors,
so combat-rule changes cannot silently retain an old result.

This CI model mirrors runtime combat semantics but does not load LÖVE. Projectile
travel is resolved at firing time, placement is reduced to coverage intervals on
the exact route length, boss packages/summoned adds and visual-frame behavior are
not modeled, and campaign unlock progression is assumed. It is deterministic
balance evidence, not a replacement for runtime integration tests or human
playtesting.

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
