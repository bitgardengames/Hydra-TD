# Hard campaign simulation assessment

Generated 2026-09-13 with `tools/balance/campaign_simulator.py` using the `hard`
difficulty and `hard` player policy, three deterministic variants per map. All 15
maps and all 20 authored waves are included. The raw simulator output now records
per-wave enemy count, kills, leaks, lives, money, flawless bonus, ability use, and
duration; use `--difficulty hard --policy hard` to reproduce it.

This is a **strong-policy stress test**, not a human playtest. “Too easy” means all
three variants cleared every listed wave without a leak. “Hard” means a wave ended
at least one run or averaged at least three leaks; “blocker” ended at least two
runs. A victory with 15 lives is especially strong evidence of excess headroom.

## Results

| Map | Victories | Final lives | Challenging waves | Leak-free waves / assessment |
|:--|--:|:--|:--|:--|
| riverbend | 3/3 | 14, 15, 15 | W10 leaked once | 19/20; too easy overall |
| switchback | 3/3 | 15, 15, 15 | None | 20/20; too easy |
| highpass | 3/3 | 15, 15, 15 | None | 20/20; too easy |
| roundabout | 3/3 | 15, 15, 15 | None | 20/20; too easy |
| gauntlet | 3/3 | 15, 15, 15 | None | 20/20; too easy |
| snaketrail | 2/3 | 15, 0, 15 | W6 leaked 5 total; **W8 ended one run** | W2–5 and W7 are easy before the spike; uneven |
| backtrack | 3/3 | 11, 15, 15 | W6 leaked 4 total | 19/20; too easy after W6 |
| lowvalley | 2/3 | 0, 5, 15 | **W1 leaked 11; W2 ended one run; W4 leaked 5** | No universally leak-free reached wave; too hard/variant-sensitive opening |
| circuit | 1/3 | 12, 0, 0 | W4 leaked 3; **W6 blocker, 30 leaks** | W1–3 and W5 easy, then an excessive W6 wall |
| outerloop | 3/3 | 15, 15, 15 | None | 20/20; too easy |
| terrace | 3/3 | 15, 13, 6 | W6 leaked 7; W7 leaked 3; W10 leaked once | 17/20; broadly easy with an early-middle bump |
| highridge | 2/3 | 0, 15, 13 | W5–7 small leaks; **W9 ended one run with 13 leaks** | W1–4 and W8 easy; sharp W9 spike |
| crossflow | 0/3 | 0, 0, 0 | **W1 leaked 28; W2 blocker, 18 leaks** | None; far too hard and not meaningfully testable beyond W2 |
| steppingstones | 2/3 | 0, 11, 8 | **W1 leaked 16; W5 leaked 8; W6 ended one run** | W2–4 easy; harsh opening and W5–6 spike |
| twinloop | 1/3 | 0, 13, 0 | **W1 leaked 18; W4 and W5 ended runs** | W2–3 easy; too hard/volatile opening |

## Campaign-level assessment

* The curve is not consistently “Hard”: six maps (`switchback`, `highpass`,
  `roundabout`, `gauntlet`, `outerloop`, and effectively `riverbend`) have almost
  no pressure even against the strongest policy, while `crossflow` prevents all
  three variants from reaching wave 3.
* Difficulty is concentrated in opening and isolated spike waves rather than a
  sustained ramp. The clearest outliers are Crossflow W1–2, Circuit W6,
  Low Valley W1–2, Twin Loop W1/W4–5, Highridge W9, Snaketrail W8, and Stepping
  Stones W1/W5–6.
* Late waves are curious: whenever the policy survives the opening, waves 11–20
  are nearly always flawless. Full-clear income and a mature 24-position defense
  outgrow the authored durability ramp. The second boss wave (W20) leaks only on
  Riverbend and Twin Loop, one enemy in one surviving variant each.
* Map order is not a smooth difficulty progression. Crossflow (map 13) is much
  harsher than the final two maps' successful variants, while several mid-campaign
  maps are perfect clears. Tune per-map openings/spikes before raising global Hard
  HP, which would worsen the blockers without fixing excess late-game purchasing
  power.
* Recommended human checks: reproduce Crossflow W1–2 and Circuit W6 first; then
  test whether legal placement geometry makes the simulator's flawless maps less
  forgiving. For easy maps, investigate lower late-wave rewards/count increases
  or stronger W11–20 compositions. For blockers, reduce opening count/HP pressure
  or increase early spacing rather than weakening their full campaign.

## Tooling corrections made during this assessment

The balance parser had silently stopped at wave 10 and evaluated the old one-piece
1→5.25 HP curve. It now discovers contiguous authored waves, models the shipped
1→3.5→5.25 midpoint curve, resolves each map's actual boss archetype, and carries
all 20 waves into challenge and economy fixtures. Challenge acceptance bands were
re-captured with ten-percent integer headroom around current shipped values.

The campaign simulator now uses the full map length for lookahead, applies flawless
bonuses for zero leaks (rather than for not using an ability), limits its abstract
placement model to 24 positions, and emits wave-level evidence. Filters for map,
difficulty, and policy make focused reproductions practical. The simulator still
resolves projectiles at firing time, abstracts placement into route coverage, and
does not model boss packages/summoned adds; conclusions should therefore direct
runtime playtests, not replace them.
