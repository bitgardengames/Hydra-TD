# Core balance fixtures

These deterministic reference captures use a straight 12-tile lane, one tower in
its best legal central tile, Hard difficulty, **no specialization and no inventory modules**, and wave-one enemy
HP. `TTK` is seconds from first shot until the last kill (`—` means the fixture
ended first); `cost` is purchase plus upgrades; `leaks` is enemy count; and
`coverage` is the percentage of spawned targets damaged by that tower. Maximum
means level 5. Upgrade costs are the shipped 0.45/0.65/0.90/1.20 purchase-cost
multipliers, parsed directly from `world/towers.lua`. Tower growth is parsed only
from each `upgrade` table in `world/tower_defs.lua`. Re-run captures after changing combat behavior, range, costs, enemy
traits, or the difficulty curve.

The acceptance rule is intentional: Lancer is the best general-purpose damage
per dollar on the single Grunt and Tank controls. Slow wins control-heavy Tank,
Cannon wins armor and packed bodies, Poison wins regeneration, Shock wins
chain-friendly packs, and Plasma wins sustained packed-lane coverage. A specialist must not
beat Lancer's cost efficiency in both control fixtures.

Values are formatted `TTK / cost / leaks / coverage`.

## Single Grunt — control (1 Grunt)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 4.4s / $50 / 0 / 100% | 0.9s / $210 / 0 / 100% |
| Lancer | 0.9s / $60 / 0 / 100% | 0.2s / $252 / 0 / 100% |
| Poison | 2.8s / $70 / 0 / 100% | 0.7s / $294 / 0 / 100% |
| Cannon | 1.5s / $90 / 0 / 100% | 0.5s / $378 / 0 / 100% |
| Shock | 2.9s / $95 / 0 / 100% | 0.8s / $399 / 0 / 100% |
| Plasma | 1.8s / $120 / 0 / 100% | 0.6s / $504 / 0 / 100% |

## Single Tank — control (1 Tank)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 10.7s / $50 / 0 / 100% | 2.4s / $210 / 0 / 100% |
| Lancer | 2.3s / $60 / 0 / 100% | 0.6s / $252 / 0 / 100% |
| Poison | 6.3s / $70 / 0 / 100% | 1.6s / $294 / 0 / 100% |
| Cannon | 2.9s / $90 / 0 / 100% | 0.8s / $378 / 0 / 100% |
| Shock | 7.2s / $95 / 0 / 100% | 1.9s / $399 / 0 / 100% |
| Plasma | 4.2s / $120 / 0 / 100% | 1.1s / $504 / 0 / 100% |

## Packed Grunts — splash/coverage (16 Grunts, 0.32s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 9 / 62% | 8.9s / $210 / 0 / 100% |
| Lancer | — / $60 / 5 / 75% | 6.8s / $252 / 0 / 100% |
| Poison | — / $70 / 6 / 69% | 7.1s / $294 / 0 / 100% |
| Cannon | 7.0s / $90 / 0 / 100% | 5.4s / $378 / 0 / 100% |
| Shock | — / $95 / 2 / 94% | 6.1s / $399 / 0 / 100% |
| Plasma | 6.3s / $120 / 0 / 100% | 4.8s / $504 / 0 / 100% |

## Bulwark — armor (4 Bulwarks, 0.8s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 4 / 25% | — / $210 / 2 / 75% |
| Lancer | — / $60 / 3 / 50% | 8.2s / $252 / 0 / 100% |
| Poison | — / $70 / 2 / 75% | 9.0s / $294 / 0 / 100% |
| Cannon | 8.4s / $90 / 0 / 100% | 4.7s / $378 / 0 / 100% |
| Shock | — / $95 / 4 / 50% | — / $399 / 1 / 100% |
| Plasma | — / $120 / 2 / 75% | 7.8s / $504 / 0 / 100% |

## Regenerator — attrition (4 Regenerators, 0.9s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 3 / 50% | 10.4s / $210 / 0 / 100% |
| Lancer | — / $60 / 1 / 100% | 7.4s / $252 / 0 / 100% |
| Poison | 9.6s / $70 / 0 / 100% | 5.1s / $294 / 0 / 100% |
| Cannon | — / $90 / 1 / 100% | 6.9s / $378 / 0 / 100% |
| Shock | — / $95 / 2 / 75% | 9.1s / $399 / 0 / 100% |
| Plasma | — / $120 / 1 / 100% | 6.6s / $504 / 0 / 100% |
## Upgrade versus equal-money expansion

Every purchase is also compared with spending its price on fractional base-tower
capacity. `Open` is marginal upgrade DPS divided by that base capacity.
`Constrained` additionally models 72% useful uptime for the next legal tile, 88%
targeting efficiency after switching/overkill, retained range coverage, and a
tower-role factor (1.05–1.28). Acceptance is **0.30–1.15 open** and **0.60–1.85
constrained**, with at least one expansion win and one constrained upgrade win;
therefore neither choice can dominate every board state. These geometry and
utility factors are fixture assumptions, not additional progression inputs.

| Tower | Tier | Cost | Base equivalents | Open | Constrained | Range |
|---|---:|---:|---:|---:|---:|---:|
| Slow | 2 | $22 | 0.45 | 0.617 | 1.294 | 4.41 tiles |
| Slow | 3 | $32 | 0.65 | 0.475 | 1.073 | 4.57 tiles |
| Slow | 4 | $45 | 0.90 | 0.377 | 0.914 | 4.73 tiles |
| Slow | 5 | $60 | 1.20 | 0.308 | 0.798 | 4.89 tiles |
| Lancer | 2 | $27 | 0.45 | 1.058 | 1.791 | 3.83 tiles |
| Lancer | 3 | $39 | 0.65 | 0.790 | 1.443 | 3.91 tiles |
| Lancer | 4 | $54 | 0.90 | 0.611 | 1.199 | 3.99 tiles |
| Lancer | 5 | $72 | 1.20 | 0.490 | 1.026 | 4.07 tiles |
| Poison | 2 | $32 | 0.45 | 0.694 | 1.326 | 3.64 tiles |
| Poison | 3 | $46 | 0.65 | 0.519 | 1.070 | 3.73 tiles |
| Poison | 4 | $63 | 0.90 | 0.403 | 0.891 | 3.82 tiles |
| Poison | 5 | $84 | 1.20 | 0.323 | 0.763 | 3.91 tiles |
| Cannon | 2 | $40 | 0.45 | 0.896 | 1.684 | 3.13 tiles |
| Cannon | 3 | $58 | 0.65 | 0.654 | 1.326 | 3.21 tiles |
| Cannon | 4 | $81 | 0.90 | 0.497 | 1.081 | 3.29 tiles |
| Cannon | 5 | $108 | 1.20 | 0.391 | 0.908 | 3.37 tiles |
| Shock | 2 | $43 | 0.45 | 0.753 | 1.407 | 3.81 tiles |
| Shock | 3 | $62 | 0.65 | 0.563 | 1.136 | 3.92 tiles |
| Shock | 4 | $86 | 0.90 | 0.437 | 0.947 | 4.03 tiles |
| Shock | 5 | $114 | 1.20 | 0.351 | 0.812 | 4.14 tiles |
| Plasma | 2 | $54 | 0.45 | 0.818 | 1.484 | 3.49 tiles |
| Plasma | 3 | $78 | 0.65 | 0.621 | 1.217 | 3.58 tiles |
| Plasma | 4 | $108 | 0.90 | 0.489 | 1.027 | 3.67 tiles |
| Plasma | 5 | $144 | 1.20 | 0.396 | 0.890 | 3.76 tiles |
