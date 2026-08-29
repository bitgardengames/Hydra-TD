# Upgrade description balance review

## Mandatory stat-only release review

The shipped campaign and replay/endless setup uses stat-only tower upgrades. For
every change to `world/tower_defs.lua`, verify the maximum-level interpolation
for damage, fire rate, range, and tower-specific status fields against the
upgrade preview and in-game result. This review is release-gating and must not
assume a specialization is selected.

Useful review commands:

```sh
rg -n "upgrade =" world/tower_defs.lua
sed -n '190,225p' world/towers.lua
sed -n '400,535p' world/towers.lua
```
