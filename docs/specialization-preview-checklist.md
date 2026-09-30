# Specialization preview manual rendering checklist

- Open every tower's specialization picker and confirm both cards restart at the
  beginning, including after closing and immediately reopening the same tower.
- Resize the window and change UI scale at small, 1080p, and high-DPI sizes. Verify
  each preview stays sharp, centered, and between its header and localized copy.
- During card intro and hover animation, verify the vignette follows the animated
  card bounds and no projectile, field, glow, or explosion escapes its rounded clip.
- Confirm the behavioral contrasts: Marksman selects the durable target; Rupture
  pierces its line; Deep Freeze nearly stops one enemy; Cold Field slows its group;
  Virulent stacks repeated poison; Contagion transfers poison; Siege concentrates
  force; Bombardment covers the spread group; Capacitor visibly charges then fires;
  Forked Lightning reaches the larger chain; Accelerator races down a narrow lane;
  and Overcharged grows while burning through the broad formation.
- Leave a picker open through several loops and verify each loop is identical. Close
  it and verify no preview animation, gameplay statistic, target, projectile, enemy,
  or effect remains active in the running wave.

# World-space scene authoring

Specialization previews are miniature gameplay scenes, not card-space animations. Paths and tower
positions use gameplay grid coordinates; enemy distances and spacing use gameplay world pixels
(`Constants.TILE` is one tile). The sandbox passes paths through `Map.createRenderContext`, constructs
normal enemies and towers, and runs the normal targeting, projectile, movement, status, and effect
systems. Never add per-preview sizes, path widths, ranges, speeds, or render scales.

Each definition owns a path, tower, enemies, and camera. Enemy entries support `kind`, `distance`
(aliases: `initialDistance` and `spawnDistance`), `spawnTime`, `count`, `spacing`, `spawnInterval`,
`healthOverride`, and deliberately opt-in `speedOverride`. Prefer the gameplay defaults. Camera
coordinates are grid coordinates and `zoom` uniformly scales the finished world into the card.
Omit the explicit center/zoom and optionally supply `camera.padding` to frame the staged path and
tower automatically; automatic framing still applies one uniform whole-world scale.

Call `SpecializationPreview.setDebug(true)` while authoring to overlay the tile grid, path centerline
and width, tower tile/range, enemy centers/bounds/path distances, coordinates, and camera bounds.
