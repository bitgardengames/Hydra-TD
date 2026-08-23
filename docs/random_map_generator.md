# Random Map Generator and Daily Runs

## Goal

Add a seeded map generator that produces a fresh battlefield while preserving
the readable, orthogonal layouts and tower-placement decisions of the authored
campaign maps. A generated map must be deterministic, quick to reject when it
is unsafe, and conservative enough that a daily run is decided by play rather
than by an impossible seed.

The first version should generate **one path, one biome, and optional water**.
Branches, multiple entrances, teleporters, and new terrain rules should wait
until the single-path generator is demonstrably reliable.

## Existing map contract

Generated output should use the same map definition consumed by
`world/map.lua`:

```lua
{
	id = "daily-2026-08-23",
	nameKey = "map.daily",
	biome = "autumn",
	path = {
		{5, 7}, {13, 7}, {13, 3}, {21, 3}, {21, 9}, {30, 9},
	},
	water = {
		{8, 10, 2},
	},
}
```

The generator must honor these current assumptions:

- The battlefield is a 32 by 14 tile grid, with 56-pixel tiles.
- Path control points are integer grid coordinates. Consecutive points are
  axis-aligned; diagonal segments are not allowed.
- The authored maps use entrances at `x = 5`, exits at `x = 30`, and lanes
  mainly between `y = 3` and `y = 11`. Keep those margins so spawning, camera
  framing, UI, and edge tower coverage continue to behave as expected.
- A path tile cannot hold a tower. Water is currently presentation data rather
  than blocked terrain, so the generator must not assume that it removes tower
  sites.
- Water entries retain the existing `{x, y, size}` representation and may not
  overlap or visually obscure the route.
- A route may revisit a control point only when an intentionally supported loop
  is introduced. The MVP rejects all repeated path tiles, avoiding ambiguous
  progress and accidental self-intersections.
- `world/map.lua` derives path length, world-space samples, last-second range,
  and the placement-based coverage multiplier. Generated definitions should go
  through that same runtime path rather than duplicating those calculations.

## Determinism and ownership

Generation must use a local pseudorandom-number generator, never Lua's global
random state. All choices derive from a versioned seed tuple:

```text
generator_version | mode | UTC_date_or_run_seed | modifier_set
```

The public daily identifier is the UTC date. Hash the tuple into the numeric
PRNG seed and store both the readable identifier and generator version in the
run record. Given the same version and tuple, every platform must produce the
same map, biome, water, waves, and modifiers. Incrementing the generator version
allows future algorithm changes without pretending old replays are compatible.

For debugging, persist the accepted candidate's seed, attempt number, map
definition, metric report, modifier IDs, and content/balance version. A daily
service should publish the resolved definition, not rely solely on clients
independently reproducing it; clients can hash the payload to detect drift.

## Generation pipeline

### 1. Select a difficulty envelope

Before drawing geometry, choose targets from measurements of the authored map
set. The initial envelope should be deliberately narrow:

- route length between the authored 20th and 80th percentiles;
- 7-11 control points and 6-10 turns;
- no segment shorter than 2 tiles;
- enough legal tower sites to support the normal economy;
- coverage multiplier near the center of the existing `0.90-1.10` clamp; and
- no topology that creates unintended double coverage where distant portions
  of the route pass within one common tower range for too long.

The exact thresholds should come from an automated report over
`world/map_defs.lua`, not from numbers copied into two systems. Store them in a
versioned generator profile such as `standard_v1` so balance changes are
reviewable.

### 2. Construct the route

Use constrained randomized backtracking rather than free-form noise:

1. Choose an entrance row from the safe vertical band and start at `x = 5`.
2. Alternate horizontal and vertical segments. Select endpoints from the
   remaining grid while respecting the target segment and turn counts.
3. Favor net progress toward `x = 30`, but permit controlled backtracking to
   create switchbacks. Put a hard budget on leftward distance.
4. Reserve a minimum Manhattan clearance around non-adjacent segments. A small
   number of close approaches may be allowed by the profile, but long parallel
   overlaps are rejected.
5. Reject repeated tiles, crossings, zero-length segments, adjacent immediate
   reversals, and any segment outside the safe band as soon as they occur.
6. Connect the final control point to an exit at `x = 30`. Backtrack if that
   connection violates any constraint.

Weight choices toward the distribution of segment lengths, turn directions,
and vertical occupancy in authored maps. This makes output feel authored
without copying whole layouts.

### 3. Reserve buildable zones

Expand the route into occupied tiles using the same semantics as
`world/map.lua`. Then compute:

- total legal tower tiles;
- legal tiles adjacent to the early, middle, and late thirds of the route;
- distinct useful build pockets (connected groups of legal tiles in practical
  tower range);
- route distance covered by at least one plausible tower site; and
- concentration of route coverage available from each site.

Require viable pockets in all three route thirds and more than one meaningful
placement plan. A map with a healthy total tile count can still be unfair if all
useful sites are at the exit or one central tile covers most of the route.

### 4. Add terrain and presentation

Choose a biome independently from the unlocked daily biome pool. Place water
only after route and build-zone validation:

1. Generate a small budget of size-1 and size-2 water features.
2. Exclude path tiles, the entrance/exit buffers, and protected build pockets.
3. Prefer clusters near unused edges and negative space rather than uniform
   scatter.
4. Re-run structural checks after placement. If water becomes blocked terrain
   in a future version, also re-run placement metrics after each feature and
   remove any feature that pushes the map outside the envelope.

Decorative scatter remains a renderer concern and must be seeded from a
separate derived stream so a cosmetic change cannot alter gameplay geometry.

### 5. Validate, score, and select

Validation has three layers:

**Structural validation (hard pass/fail)**

- in-bounds integer points and orthogonal, non-zero segments;
- correct entrance and exit columns;
- continuous route with no repeated tiles or self-intersections;
- minimum/maximum route, segment, and turn counts;
- terrain does not block the route; and
- runtime map construction completes with finite, non-zero derived metrics.

**Static playability validation (hard bands plus a score)**

- buildable tile and pocket distribution;
- early/mid/late route coverage;
- `coverageMult` and path length within the chosen authored envelope;
- no single dominant tower site and no excessive parallel-lane overlap; and
- sufficient reaction distance after the entrance and before the exit.

**Headless balance validation (hard pass/fail)**

Run several deterministic baseline strategies against the actual daily waves:

- a simple legal-placement bot must survive the opening waves, proving that the
  economy can get started;
- at least one competent mixed-tower strategy must be able to complete the run;
- an intentionally weak strategy must not win reliably; and
- small deterministic variations in placement must not change the outcome from
  easy win to immediate loss too often.

Generate a fixed candidate pool (for example, 64 attempts), retain only full
passes, then choose the highest-scoring candidate with the seed as a stable
tiebreaker. Never loop until success: bounded work is necessary for identical
results and predictable startup. If no candidate passes, serve a prevalidated
fallback map selected by the same seed. A fallback is preferable to relaxing a
hard safety rule.

## Waves and geometry

For the MVP, use a prevalidated wave schedule appropriate to the selected
difficulty profile rather than generating geometry and wave difficulty at the
same time. Apply the runtime's existing map coverage compensation, then apply
daily modifiers. This keeps failures attributable: geometry validation answers
whether a map is fair, while wave tuning answers whether the challenge is fair.

Once sufficient telemetry exists, wave templates may be selected by broad map
traits (short/long route, concentrated/distributed pockets), but must still pass
the headless balance gate as one combined run definition.

## Daily modifiers

Modifiers are data, chosen before candidate validation and shown before the run.
The map and wave simulator must validate the exact modifier set players receive.
An initial daily should have one modifier; later, curated compatible pairs can
be introduced.

### SWARM

**Enemies have 60% health. Waves contain 60% more enemies.**

- Multiply enemy maximum and current health by `0.60` at spawn.
- Multiply each scheduled group count by `1.60`, using deterministic rounding
  with a minimum of one. Do not multiply boss count or boss-summoned adds.
- Preserve the original group duration where possible by reducing spawn
  intervals, but enforce a safe minimum interval and alive-enemy cap.
- Keep per-kill rewards unchanged initially; the larger population is part of
  the mode's economy and splash-tower fantasy. Monitor whether this produces
  runaway income.

### BLITZ

**Enemies move 25% faster.**

- Multiply base movement speed by `1.25` after enemy-type stats are resolved.
- Apply the multiplier consistently to normal movement and speed-restoring
  effects, while slows continue to multiply the resulting speed.
- Validate reaction distance especially strictly on short maps.

### FORTIFIED

**Enemies have 40% more health. Fewer enemies spawn.**

- Multiply enemy maximum and current health by `1.40` at spawn.
- Start with group counts multiplied by `0.75`, deterministically rounded with
  a minimum of one; tune this value from simulation rather than silently
  changing the displayed health rule.
- Do not reduce boss count. Decide explicitly whether boss health is modified;
  the recommended MVP applies the health multiplier to bosses and validates
  boss waves separately.
- Keep per-kill rewards unchanged initially. The reduced population makes
  single-target damage valuable while constraining income.

### RELENTLESS

**The next wave automatically begins.**

- Start wave 1 after the normal initial preparation period.
- Start each later wave immediately when the previous wave is fully spawned;
  waves may overlap while earlier enemies remain alive.
- Disable manual wave-start input and any early-start reward so automation
  cannot grant free income.
- Preserve all between-wave bookkeeping at the scheduled start boundary and
  clearly preview the next wave with a countdown.

### ONE LIFE

**One leak ends the run.**

- Set starting and maximum lives to one; use the normal life-based defeat path
  rather than adding a second loss condition.
- Ignore sources of bonus lives for this run, if such sources are added later.
- Always show the modifier on the HUD because it changes the consequence of a
  single mistake.

### Modifier composition rules

Use stable stat stages so combinations cannot depend on callback order:

```text
enemy definition -> wave/profile scaling -> daily health/count/speed scaling
-> runtime statuses and auras -> final clamping
```

Initially disallow **SWARM + FORTIFIED** because their opposing population and
health identities become unclear. Treat **RELENTLESS + BLITZ** and any **ONE
LIFE** pair as high difficulty and withhold them until combined simulations and
completion telemetry show a reasonable win band. Modifier IDs and numeric
parameters belong in the replay/run record, never only in localized text.

## Daily-run lifecycle

1. At UTC rollover, resolve the date, modifier set, generator/profile version,
   map candidate, biome, and wave template.
2. Run all validators and publish the immutable run definition and hash.
3. The client displays the map preview, modifier rules, date, and time remaining.
4. Starting a run snapshots the definition. A rollover never changes a run in
   progress.
5. Scores are accepted only with matching definition hash and gameplay/content
   version. Leaderboards should separate incompatible versions.
6. A practice run may reuse a past definition but must be clearly ineligible for
   the daily leaderboard and campaign progression.

The fairest leaderboard permits one scored attempt per day. If unlimited
attempts are desired, rank by a transparent tuple such as completion, leaks,
time, and score, and label the attempt count so memorization is visible.

## Telemetry and acceptance targets

Record generation attempt/rejection reasons without player data, and for played
runs record the definition hash, modifier set, completion, loss wave, leaks,
tower mix, placements by route third, and run duration. Use this to find seeds
that technically pass but produce unusual difficulty or repetitive strategies.

Before launch, generate at least 10,000 seeds per modifier and require:

- 100% structural validation or deterministic fallback;
- no crashes, hangs, NaN metrics, blocked routes, or maps with zero viable
  opening placements;
- fallback frequency below an agreed threshold (target below 0.5%);
- stable generation results across supported platforms; and
- simulated completion and early-loss rates inside modifier-specific bands.

Human playtests should blind-test generated maps beside authored maps. Reviewers
should rate readability, placement variety, perceived fairness, and whether the
modifier—not a geometry accident—explains the run's difficulty.

## Implementation sequence

1. Build an authored-map metric reporter and commit the `standard_v1` envelope.
2. Implement a pure seeded route generator returning a normal map definition.
3. Add structural/static validators, rejection diagnostics, candidate scoring,
   serialization, and deterministic fixture seeds.
4. Add protected-pocket-aware water placement and preview/export support.
5. Integrate headless baseline simulations and the prevalidated fallback pool.
6. Implement modifiers as declarative run rules with unit tests for rounding,
   bosses, rewards, wave overlap, and loss behavior.
7. Add the daily selection UI, immutable run snapshot, replay hash, and local
   history; add an online leaderboard only after validation is trusted.
8. Run the large seed sweep and blind playtest, then tune profiles by versioning
   them rather than changing already published dailies.

This sequence produces a useful offline seeded mode before requiring a daily
service, and it keeps every stage inspectable when a map is rejected or a run
feels unfair.
