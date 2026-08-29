# Core balance fixtures

These deterministic reference captures use a straight 12-tile lane, one tower in
its best legal central tile, Hard difficulty, **no specialization**, and wave-one enemy
HP. `TTK` is seconds from first shot until the last kill (`—` means the fixture
ended first); `cost` is purchase plus upgrades; `leaks` is enemy count; and
`coverage` is the percentage of spawned targets damaged by that tower. Maximum
means level 5. Upgrade costs are the shipped 0.5625/0.8125/1.125/1.50 purchase-cost
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
| Slow | 4.4s / $50 / 0 / 100% | 0.9s / $250 / 0 / 100% |
| Lancer | 0.9s / $60 / 0 / 100% | 0.2s / $300 / 0 / 100% |
| Poison | 2.8s / $70 / 0 / 100% | 0.7s / $350 / 0 / 100% |
| Cannon | 1.5s / $90 / 0 / 100% | 0.5s / $450 / 0 / 100% |
| Shock | 2.9s / $95 / 0 / 100% | 0.8s / $475 / 0 / 100% |
| Plasma | 1.8s / $120 / 0 / 100% | 0.6s / $600 / 0 / 100% |

## Single Tank — control (1 Tank)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 10.7s / $50 / 0 / 100% | 2.4s / $250 / 0 / 100% |
| Lancer | 2.3s / $60 / 0 / 100% | 0.6s / $300 / 0 / 100% |
| Poison | 6.3s / $70 / 0 / 100% | 1.6s / $350 / 0 / 100% |
| Cannon | 2.9s / $90 / 0 / 100% | 0.8s / $450 / 0 / 100% |
| Shock | 7.2s / $95 / 0 / 100% | 1.9s / $475 / 0 / 100% |
| Plasma | 4.2s / $120 / 0 / 100% | 1.1s / $600 / 0 / 100% |

## Packed Grunts — splash/coverage (16 Grunts, 0.32s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 9 / 62% | 8.9s / $250 / 0 / 100% |
| Lancer | — / $60 / 5 / 75% | 6.8s / $300 / 0 / 100% |
| Poison | — / $70 / 6 / 69% | 7.1s / $350 / 0 / 100% |
| Cannon | 7.0s / $90 / 0 / 100% | 5.4s / $450 / 0 / 100% |
| Shock | — / $95 / 2 / 94% | 6.1s / $475 / 0 / 100% |
| Plasma | 6.3s / $120 / 0 / 100% | 4.8s / $600 / 0 / 100% |

## Bulwark — armor (4 Bulwarks, 0.8s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 4 / 25% | — / $250 / 2 / 75% |
| Lancer | — / $60 / 3 / 50% | 8.2s / $300 / 0 / 100% |
| Poison | — / $70 / 2 / 75% | 9.0s / $350 / 0 / 100% |
| Cannon | 8.4s / $90 / 0 / 100% | 4.7s / $450 / 0 / 100% |
| Shock | — / $95 / 4 / 50% | — / $475 / 1 / 100% |
| Plasma | — / $120 / 2 / 75% | 7.8s / $600 / 0 / 100% |

## Regenerator — attrition (4 Regenerators, 0.9s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 3 / 50% | 10.4s / $250 / 0 / 100% |
| Lancer | — / $60 / 1 / 100% | 7.4s / $300 / 0 / 100% |
| Poison | 9.6s / $70 / 0 / 100% | 5.1s / $350 / 0 / 100% |
| Cannon | — / $90 / 1 / 100% | 6.9s / $450 / 0 / 100% |
| Shock | — / $95 / 2 / 75% | 9.1s / $475 / 0 / 100% |
| Plasma | — / $120 / 1 / 100% | 6.6s / $600 / 0 / 100% |
## Upgrade versus equal-money expansion

Every purchase is also compared with spending its price on fractional base-tower
capacity. `Open` is marginal upgrade DPS divided by that base capacity.
`Constrained` additionally models 72% useful uptime for the next legal tile, 88%
targeting efficiency after switching/overkill, retained range coverage, and a
tower-role factor (1.05–1.28). Acceptance is **0.24–1.15 open** and **0.60–1.85
constrained**, with at least one expansion win and one constrained upgrade win;
therefore neither choice can dominate every board state. These geometry and
utility factors are fixture assumptions, not additional progression inputs.

| Tower | Tier | Cost | Base equivalents | Open | Constrained | Range |
|---|---:|---:|---:|---:|---:|---:|
| Slow | 2 | $28 | 0.5625 | 0.494 | 1.035 | 4.41 tiles |
| Slow | 3 | $41 | 0.8125 | 0.380 | 0.858 | 4.57 tiles |
| Slow | 4 | $56 | 1.125 | 0.302 | 0.731 | 4.73 tiles |
| Slow | 5 | $75 | 1.5 | 0.246 | 0.638 | 4.89 tiles |
| Lancer | 2 | $34 | 0.5625 | 0.846 | 1.433 | 3.83 tiles |
| Lancer | 3 | $49 | 0.8125 | 0.632 | 1.154 | 3.91 tiles |
| Lancer | 4 | $68 | 1.125 | 0.489 | 0.959 | 3.99 tiles |
| Lancer | 5 | $90 | 1.5 | 0.392 | 0.821 | 4.07 tiles |
| Poison | 2 | $39 | 0.5625 | 0.555 | 1.061 | 3.64 tiles |
| Poison | 3 | $57 | 0.8125 | 0.415 | 0.856 | 3.73 tiles |
| Poison | 4 | $79 | 1.125 | 0.322 | 0.713 | 3.82 tiles |
| Poison | 5 | $105 | 1.5 | 0.258 | 0.610 | 3.91 tiles |
| Cannon | 2 | $51 | 0.5625 | 0.717 | 1.347 | 3.13 tiles |
| Cannon | 3 | $73 | 0.8125 | 0.523 | 1.061 | 3.21 tiles |
| Cannon | 4 | $101 | 1.125 | 0.398 | 0.865 | 3.29 tiles |
| Cannon | 5 | $135 | 1.5 | 0.313 | 0.726 | 3.37 tiles |
| Shock | 2 | $53 | 0.5625 | 0.602 | 1.126 | 3.81 tiles |
| Shock | 3 | $77 | 0.8125 | 0.450 | 0.909 | 3.92 tiles |
| Shock | 4 | $107 | 1.125 | 0.350 | 0.758 | 4.03 tiles |
| Shock | 5 | $143 | 1.5 | 0.281 | 0.650 | 4.14 tiles |
| Plasma | 2 | $68 | 0.5625 | 0.654 | 1.187 | 3.49 tiles |
| Plasma | 3 | $98 | 0.8125 | 0.497 | 0.974 | 3.58 tiles |
| Plasma | 4 | $135 | 1.125 | 0.391 | 0.822 | 3.67 tiles |
| Plasma | 5 | $180 | 1.5 | 0.317 | 0.712 | 3.76 tiles |
