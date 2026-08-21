# Upgrade description balance review

## Mandatory stat-only release review

The shipped campaign and replay/endless setup uses stat-only tower upgrades. For
every change to `world/tower_defs.lua`, verify the maximum-level interpolation
for damage, fire rate, range, and tower-specific status fields against the
upgrade preview and in-game result. This review is release-gating and must not
assume a specialization or module is selected.

Useful review commands:

```sh
rg -n "upgrade =" world/tower_defs.lua
sed -n '190,225p' world/towers.lua
sed -n '400,535p' world/towers.lua
```

## Experimental module description QA

The files `world/tower_branch_defs.lua`, `systems/module_defs.lua`, and
`ui/module_picker.lua` are retained for explicitly enabled internal module
playtests. Their copy review is separate, non-release-gating experimental QA:
enable one deliberately with
`require("systems.modules").enableExperimentalPlaytest()` before starting it.

1. List experimental IDs from `world/tower_branch_defs.lua` and confirm each has
   a `moduleDesc` entry in `languages/enUS.lua`.
2. Compare each ID's behavior data in `systems/module_defs.lua` with its English
   description and the corresponding handler in `world/projectile_behaviors.lua`.
3. Record every damage multiplier, conditional bonus, follow-up projectile or
   burst multiplier, tick interval, and meaningful stack/damage cap in one or
   two short clauses.
4. Treat replacement multipliers as total damage, separately emitted bonuses as
   bonus damage, chain `falloff` as retained damage per jump, poison
   `rampPerTick` as an increment toward `rampMax`, and `tick_damage.rate` as
   seconds between full projectile-damage ticks.
5. Check copy at the narrowest supported picker width; prefer compact clauses
   over smaller text.

```sh
sed -n '30,75p' world/tower_branch_defs.lua
sed -n '500,980p' systems/module_defs.lua
sed -n '235,300p' languages/enUS.lua
rg -n 'B\.(hit_chain|fork_chain|chain_static_surge|apply_poison|tick_damage)' world/projectile_behaviors.lua
```
