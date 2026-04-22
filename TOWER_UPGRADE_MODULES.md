# Tower Upgrade Modules: Projectile & Damage Payload Reference

This document explains what each **tower upgrade module** (the choices from `world/tower_branch_defs.lua`) does to the spawned projectile behavior and/or damage payload.

## How to read this
- **Projectile shape/movement** = how the projectile travels or outputs hits.
- **Damage payload** = direct damage, AoE, DoT/tick effects, chaining, split logic, status applications.
- **Targeting only** modules are called out explicitly (no projectile payload changes).

---

## Specialization modules (replace the tower's behavior package)
These modules use `addSpec(...)` in `systems/module_defs.lua`, which replaces the tower behavior list with a curated set.

### Slow tower
- **`slow_glacier_core`**
  - Homing single-hit projectile (`move_homing` + `hit_damage`) that applies stronger/longer slow (`factor=0.42`, `dur=2.3`).
- **`slow_permafrost`**
  - Homing hit + slow (`0.58`, `1.6`) plus AoE splash damage (`aoe_damage radius=34`).
- **`slow_frost_nova`**
  - Homing hit + slow (`0.5`, `1.7`) and spawns a static field (`spawn_static_field radius=42`) that ticks AoE damage over time.
- **`slow_shatterburst`**
  - Homing hit + slow (`0.52`, `1.4`) plus `frost_shatter` (spawns 6 shard projectiles at `0.45x` damage each if target is slowed).
- **`slow_cold_snap`**
  - Homing hit + slow (`0.5`, `1.5`) plus `slow_pop` (bonus local burst damage if target is currently slowed).
- **`slow_black_ice`**
  - Homing hit + slow (`0.46`, `2.0`) plus AoE splash (`radius=38`).
- **`slow_absolute_zero`**
  - Homing hit + heavy slow (`0.4`, `2.4`) plus both shatter (`8` shards at `0.55x`) and static field (`radius=48`).
- **`slow_hailstorm`**
  - Homing hit + slow (`0.56`, `1.4`) plus split-on-hit (`count=2`) and slow-pop detonation behavior.

### Lancer tower
- **`lancer_deadeye`**
  - Homing projectile with `hit_circle radius=9` contact detection and normal hit damage.
- **`lancer_volley`**
  - Homing hit that splits into 2 child projectiles on hit (`split_on_hit count=2`, each child defaults to `0.6x` parent damage in behavior logic).
- **`lancer_arc_lance`** *(not currently offered in branch choices, but defined)*
  - Homing hit with chain damage (`jumps=2`, `radius=54`).

### Poison tower
- **`poison_blight`**
  - Homing hit + normal damage + poison application (`dps=6.2`, `dur=2.2`, `maxStacks=7`).
- **`poison_plague`**
  - Homing hit + normal damage + high-stack poison (`dps=2.6`, `dur=2.2`, `maxStacks=22`).
- **`poison_neurotoxin`**
  - Homing hit + normal damage + mid/high poison (`dps=4.2`, `dur=2.1`, `maxStacks=10`).

### Cannon tower
- **`cannon_seige`**
  - Homing shell with `hit_circle radius=12` and AoE explosion damage (`aoe_damage radius=58`).
- **`cannon_cluster`**
  - Homing shell with AoE (`radius=38`) plus split-on-hit into 2 child shots.
- **`cannon_aftershock`**
  - Homing shell with AoE (`radius=44`) plus static field spawn (`radius=52`).

### Shock tower
- **`shock_storm`**
  - Converts to target-anchored emission (`emit_on_target`) and applies chain damage (`jumps=6`, `radius=62`) on hit event.
- **`shock_conductor`** *(not currently offered in branch choices, but defined)*
  - Emission + chain damage (`jumps=3`, `radius=60`) + static field spawn (`radius=56`).
- **`shock_overload`**
  - Emission + chain (`jumps=3`, `radius=56`) + orbital spawn on hit (`count=2`, each orbital runs tick damage).

### Plasma tower
- **`plasma_lance`**
  - Linear projectile with fast tick damage aura (`tick_damage radius=13`, `rate=0.09`).
- **`plasma_supernova`**
  - Linear projectile with tick aura (`radius=15`, `rate=0.12`) plus AoE splash (`radius=36`) on hit.
- **`plasma_vortex`**
  - Spiral projectile with tick aura (`radius=12`, `rate=0.1`) and growth scaling (`scale=1.8`) that increases radius and damage over life.

---

## Generic upgrade modules used in branch trees
These are applied by `apply(ctx)` mutators and stack with the current projectile package.

- **`pierce`**
  - Forces linear travel (replaces homing with `move_linear`), ensures hit detection exists, and adds `pierce` behavior.
  - Runtime effect: projectile does not consume on hit, tracks already-hit targets, can pass through multiple enemies (optionally capped by `maxHits`, default infinite).

- **`move_linear`**
  - Replaces homing with straight-line velocity from tower firing angle.

- **`move_boomerang`**
  - Adds outbound then return-to-tower movement (`dist=180` default in module application).

- **`orbit_shot`**
  - Adds launch-then-orbit movement around launch center (`radius=48`, `speed=4`).

- **`move_spiral`**
  - Adds forward movement with sinusoidal perpendicular spiral offset (`amp=12`, `freq=8`).

- **`chain_hit`**
  - Adds/extends `hit_chain` behavior.
  - If chain exists: `jumps +2`, `radius +12`; otherwise initializes chain (`jumps=3`, `radius=72`).
  - Runtime chain damage starts from current projectile damage and falls off per jump (`falloff` default `0.75`).

- **`chain_fork`**
  - Adds `fork_chain` behavior (`radius=52`, `dmgMult=0.35`).
  - Runtime: after a chain is built, each chain endpoint can fork to one nearby extra target for 35% damage.

- **`split_on_hit`**
  - Adds split behavior (`count=2`).
  - Runtime: on hit, spawns child projectiles in a cone, each at `dmgMult` default `0.6` of parent damage.

- **`spawn_orbitals`**
  - Adds `spawn_orbital_on_hit` (`count=2`) with `noInherit=true`.
  - Runtime: on primary hit only, spawns orbiting child projectiles that tick damage (`tick_damage radius=28`, `rate=0.25`) at `0.4x` parent damage.

- **`infect_spread`**
  - Marks hit enemies with infection metadata (`radius=48`).
  - Runtime payload change occurs on infected enemy death: poison stacks are copied/spread to nearby enemies (not direct burst damage).

- **`tick_damage`**
  - Adds periodic AoE ticking behavior (`radius=16`, `rate=0.2`) around projectile position.
  - Runtime: emits repeated damage events and periodic hit events while enemies remain inside radius.

- **`growing_projectile`**
  - Adds growth over projectile lifetime (`scale=2.2`).
  - Runtime: scales projectile radius/hit radius and scales damage from base damage by growth factor.

- **`chaos_bounce`**
  - On hit, randomizes projectile velocity direction and clears current hit target.
  - Note: module defs comment says this is currently not working as intended.

- **`target_low_hp`**
  - **Targeting-only**: switches tower targeting mode to lowest HP. No direct payload mutation.

- **`target_farthest_progress`**
  - **Targeting-only**: switches targeting mode to furthest path progress. No direct payload mutation.

- **`target_farthest_range`**
  - **Targeting-only**: switches targeting mode to farthest-in-range target. No direct payload mutation.

---

## Implementation notes (for future balancing)
- `growing_projectile` influences multiple payload systems because both `aoe_damage` and `hit_chain` read shared growth scale (`p._growthScale`) and/or scaled damage.
- `spawn_orbitals` and `split_on_hit` are marked `noInherit` in module application, so child projectiles do not recursively inherit the full parent module stack by default.
- Beam conversion exists as a module (`beam_conversion`) but is not currently in the tower branch upgrade choices.
