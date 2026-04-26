# Factorio-Style Performance Plan for Hydra TD

Factorio feels smooth because it does **predictable work per tick**, minimizes cache misses, and avoids allocating garbage in hot loops.

## What Hydra TD already does well

- **Fixed-step simulation with capped catch-up work** (`1/60` tick, max sim steps, clamped backlog). This is the core anti-hitch strategy and matches the “stable tick” model.  
- **Simulation and rendering are separated**, with interpolation alpha (`State.renderAlpha`) for smooth visuals between fixed updates.  
- **Spatial partitioning for enemy queries** using `world/spatial_grid.lua`, reducing worst-case targeting scans.  
- **Swap-remove patterns** in several hot lists to keep removals O(1) and avoid table shifting.

## What to add next (highest impact first)

## 1) Enforce per-system frame budgets

Give each hot system a hard budget target (example at 60 FPS):

- Enemies update: <= 2.0 ms
- Towers + targeting: <= 1.5 ms
- Projectiles: <= 1.0 ms
- Effects + floaters: <= 0.7 ms
- Draw world + entities + UI: <= 4.0 ms
- Headroom (GC, OS jitter, spikes): >= 3.0 ms

If a system exceeds budget, degrade gracefully *that frame* (e.g., lower FX density), rather than stalling everything.

## 2) Convert hot entity loops to data-oriented storage

Lua tables per-entity are convenient but expensive at scale. For the most updated fields, migrate toward structure-of-arrays style storage:

- `enemyX[i], enemyY[i], enemyHP[i], enemySpeed[i], ...`

Benefits:

- fewer table/hash lookups
- tighter memory access patterns
- easier vector-like loop optimizations

Do this incrementally: start with movement + targeting-critical fields.

## 3) Pool transient objects aggressively

Avoid creating/destroying tables in hot paths:

- projectile instances
- hit/effect descriptors
- floater entries
- temporary query result tables

Re-use fixed-capacity buffers and object pools. This directly reduces GC spikes (the #1 source of “random hitching” in Lua games).

## 4) Use event queues instead of immediate side effects in inner loops

In the tight update loops, append compact events:

- `damage(enemyId, amount)`
- `spawnProjectile(type, x, y, targetId)`
- `playSfx(id)`

Then process events in dedicated phases. This lowers branching chaos, improves determinism, and keeps hot loops linear.

## 5) Batch and simplify rendering under load

When enemy count grows:

- prefer sprite batches / mesh batching where possible
- reduce expensive state changes
- skip non-essential outlines/shadows/trails based on quality tier
- decimate cosmetic animation update rates (e.g., animate every 2nd tick for non-critical visuals)

Gameplay should stay full-rate; cosmetics can degrade first.

## 6) Add a live performance HUD (always-on in dev)

Track rolling stats (avg, p95, p99):

- frame ms
- update ms by subsystem
- draw ms by subsystem
- GC step/collect time and memory delta
- entity counts (enemies/projectiles/effects)
- backlog clamp count (`State.simDebug.backlogClampEvents`)

Ship a hidden debug toggle so performance regressions are obvious immediately.

## 7) Stress-test scenarios as part of CI/manual gates

Create deterministic “worst-case” scenes:

- high enemy count with dense tower fire
- lots of chained effects + UI floaters
- pathing-heavy wave transitions

Reject changes that regress p95/p99 frametime beyond agreed thresholds.

## 8) Keep determinism and amortize expensive work

Spread expensive one-shot tasks over multiple ticks:

- map decoration/scatter updates
- expensive recomputations
- cache invalidations

Never do large burst work in one frame if it can be amortized.

## Quick implementation order

1. Performance HUD + per-system timers.  
2. Object pools for projectiles/effects/floaters.  
3. Data-oriented enemy storage for movement + targeting fields.  
4. Render quality ladder for high-load frames.  
5. Deterministic stress scenes + regression thresholds.

If these five are done well, Hydra TD can sustain “hundreds of moving objects” smoothly with far fewer stalls.
