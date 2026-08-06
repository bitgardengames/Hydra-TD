# Core balance fixtures

These deterministic reference captures use a straight 12-tile lane, one tower in
its best legal central tile, Normal difficulty, no modules, and wave-one enemy
HP. `TTK` is seconds from first shot until the last kill (`—` means the fixture
ended first); `cost` is purchase plus upgrades; `leaks` is enemy count; and
`coverage` is the percentage of spawned targets damaged by that tower. Maximum
means level 5. Upgrade costs are the shipped 1.25/1.75/2.4/3.2 purchase-cost
multipliers. Re-run captures after changing combat behavior, range, costs, enemy
traits, or the difficulty curve.

The acceptance rule is intentional: Lancer is the best general-purpose damage
per dollar on the single Grunt and Tank controls. Slow wins control-heavy Tank,
Cannon wins armor and packed bodies, Poison wins regeneration, Shock wins
shields, and Plasma wins sustained packed-lane coverage. A specialist must not
beat Lancer's cost efficiency in both control fixtures.

Values are formatted `TTK / cost / leaks / coverage`.

## Single Grunt — control (1 Grunt)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 4.4s / $50 / 0 / 100% | 0.9s / $480 / 0 / 100% |
| Lancer | 0.9s / $60 / 0 / 100% | 0.2s / $576 / 0 / 100% |
| Poison | 2.8s / $70 / 0 / 100% | 0.7s / $672 / 0 / 100% |
| Cannon | 1.5s / $90 / 0 / 100% | 0.5s / $864 / 0 / 100% |
| Shock | 2.9s / $95 / 0 / 100% | 0.8s / $912 / 0 / 100% |
| Plasma | 1.8s / $120 / 0 / 100% | 0.6s / $1152 / 0 / 100% |

## Single Tank — control (1 Tank)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | 10.7s / $50 / 0 / 100% | 2.4s / $480 / 0 / 100% |
| Lancer | 2.3s / $60 / 0 / 100% | 0.6s / $576 / 0 / 100% |
| Poison | 6.3s / $70 / 0 / 100% | 1.6s / $672 / 0 / 100% |
| Cannon | 2.9s / $90 / 0 / 100% | 0.8s / $864 / 0 / 100% |
| Shock | 7.2s / $95 / 0 / 100% | 1.9s / $912 / 0 / 100% |
| Plasma | 4.2s / $120 / 0 / 100% | 1.1s / $1152 / 0 / 100% |

## Packed Grunts — splash/coverage (16 Grunts, 0.32s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 9 / 62% | 8.9s / $480 / 0 / 100% |
| Lancer | — / $60 / 5 / 75% | 6.8s / $576 / 0 / 100% |
| Poison | — / $70 / 6 / 69% | 7.1s / $672 / 0 / 100% |
| Cannon | 7.0s / $90 / 0 / 100% | 5.4s / $864 / 0 / 100% |
| Shock | — / $95 / 2 / 94% | 6.1s / $912 / 0 / 100% |
| Plasma | 6.3s / $120 / 0 / 100% | 4.8s / $1152 / 0 / 100% |

## Bulwark — armor (4 Bulwarks, 0.8s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 4 / 25% | — / $480 / 2 / 75% |
| Lancer | — / $60 / 3 / 50% | 8.2s / $576 / 0 / 100% |
| Poison | — / $70 / 2 / 75% | 9.0s / $672 / 0 / 100% |
| Cannon | 8.4s / $90 / 0 / 100% | 4.7s / $864 / 0 / 100% |
| Shock | — / $95 / 4 / 50% | — / $912 / 1 / 100% |
| Plasma | — / $120 / 2 / 75% | 7.8s / $1152 / 0 / 100% |

## Regenerator — attrition (4 Regenerators, 0.9s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 3 / 50% | 10.4s / $480 / 0 / 100% |
| Lancer | — / $60 / 1 / 100% | 7.4s / $576 / 0 / 100% |
| Poison | 9.6s / $70 / 0 / 100% | 5.1s / $672 / 0 / 100% |
| Cannon | — / $90 / 1 / 100% | 6.9s / $864 / 0 / 100% |
| Shock | — / $95 / 2 / 75% | 9.1s / $912 / 0 / 100% |
| Plasma | — / $120 / 1 / 100% | 6.6s / $1152 / 0 / 100% |

## Shieldbearer — shield/chain (6 Shieldbearers, 0.55s spacing)
| Tower | Base | Maximum |
|---|---:|---:|
| Slow | — / $50 / 5 / 50% | — / $480 / 2 / 83% |
| Lancer | — / $60 / 4 / 67% | 9.0s / $576 / 0 / 100% |
| Poison | — / $70 / 4 / 67% | 9.7s / $672 / 0 / 100% |
| Cannon | — / $90 / 2 / 83% | 7.2s / $864 / 0 / 100% |
| Shock | 8.8s / $95 / 0 / 100% | 5.3s / $912 / 0 / 100% |
| Plasma | — / $120 / 2 / 83% | 7.5s / $1152 / 0 / 100% |
