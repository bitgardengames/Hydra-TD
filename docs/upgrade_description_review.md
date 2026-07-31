# Upgrade description balance review

Run this review whenever an active tower upgrade's behavior data changes.

1. List active IDs from `world/tower_branch_defs.lua` and confirm each has a
   `moduleDesc` entry in `languages/enUS.lua`.
2. Compare each active ID's `addSpec` behavior data in `systems/module_defs.lua`
   with its English description. Search the corresponding handler in
   `world/projectile_behaviors.lua` before interpreting a field.
3. Record every damage multiplier, conditional bonus, follow-up projectile or
   burst multiplier, tick interval, and meaningful stack/damage cap. Keep the
   result to one or two short clauses.
4. Convert values according to their handler semantics:
   - A multiplier replacing total damage, such as `mult = 0.88`, is
     **−12% damage**.
   - A separately emitted bonus, such as `bonusDmgMult = 0.55`, is
     **+55% damage**.
   - Chain `falloff` is the damage retained on every successive jump.
   - Poison `rampPerTick` adds to its total-damage multiplier each poison tick;
     `rampMax` is the maximum total multiplier.
   - Plasma `tick_damage.rate` is seconds between full projectile-damage ticks;
     endpoint `dmgMult` values are total burst damage, not bonus damage.
5. Check the copy at the narrowest supported card width in
   `ui/module_picker.lua`; prefer compact clauses over smaller text.

Useful review commands:

```sh
sed -n '30,75p' world/tower_branch_defs.lua
sed -n '500,980p' systems/module_defs.lua
sed -n '235,300p' languages/enUS.lua
rg -n 'B\.(hit_chain|fork_chain|chain_static_surge|apply_poison|tick_damage)' world/projectile_behaviors.lua
```
