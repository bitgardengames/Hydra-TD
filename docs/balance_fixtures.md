# Core balance fixtures

These deterministic reference captures use a straight 12-tile lane, one tower in
its best legal central tile, Hard difficulty, **no specialization and no inventory modules**, and wave-one enemy
HP. `TTK` is seconds from first shot until the last kill (`—` means the fixture
ended first); `cost` is purchase plus upgrades; `leaks` is enemy count; and
`coverage` is the percentage of spawned targets damaged by that tower. Maximum
means level 5. Upgrade costs are the shipped 0.5625/0.8125/1.125/1.50 purchase-cost
multipliers, parsed directly from `world/towers.lua`. Tower growth is parsed only
from each `upgrade` table in `world/tower_defs.lua`. Re-run captures after changing combat behavior, range, costs, enemy
traits, or the difficulty curve.

The acceptance rule is intentional: Lancer is the best general-purpose damage
per dollar on the single Grunt control. Cannon wins armor and packed bodies, Poison wins regeneration, Shock wins
chain-friendly packs, and Plasma wins sustained packed-lane coverage. A specialist must not
beat Lancer's cost efficiency in the baseline control fixture.

Values are formatted `TTK / cost / leaks / coverage`.

## Single Grunt — control (1 Grunt)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 4.4s / $50 / 0 / 100% | 0.9s / $375 / 0 / 100% |
| Lancer | 0.9s / $60 / 0 / 100% | 0.2s / $450 / 0 / 100% |
| Poison | 2.8s / $70 / 0 / 100% | 0.7s / $525 / 0 / 100% |
| Cannon | 1.5s / $90 / 0 / 100% | 0.5s / $675 / 0 / 100% |
| Shock | 2.9s / $95 / 0 / 100% | 0.8s / $712 / 0 / 100% |
| Plasma | 1.8s / $120 / 0 / 100% | 0.6s / $900 / 0 / 100% |

## Packed Grunts — splash/coverage (16 Grunts, 0.32s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 9 / 62% | 8.9s / $375 / 0 / 100% |
| Lancer | — / $60 / 5 / 75% | 6.8s / $450 / 0 / 100% |
| Poison | — / $70 / 6 / 69% | 7.1s / $525 / 0 / 100% |
| Cannon | 7.0s / $90 / 0 / 100% | 5.4s / $675 / 0 / 100% |
| Shock | — / $95 / 2 / 94% | 6.1s / $712 / 0 / 100% |
| Plasma | 6.3s / $120 / 0 / 100% | 4.8s / $900 / 0 / 100% |

## Regenerator — attrition (4 Regenerators, 0.9s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 3 / 50% | 10.4s / $375 / 0 / 100% |
| Lancer | — / $60 / 1 / 100% | 7.4s / $450 / 0 / 100% |
| Poison | 9.6s / $70 / 0 / 100% | 5.1s / $525 / 0 / 100% |
| Cannon | — / $90 / 1 / 100% | 6.9s / $675 / 0 / 100% |
| Shock | — / $95 / 2 / 75% | 9.1s / $712 / 0 / 100% |
| Plasma | — / $120 / 1 / 100% | 6.6s / $900 / 0 / 100% |
