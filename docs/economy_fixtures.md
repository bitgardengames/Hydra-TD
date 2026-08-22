# Campaign economy fixtures

`tools/balance/economy_fixtures.py` is a dependency-free planning model for all
15 maps and all 10 authored waves in `systems/campaign_wave_defs.lua`. It parses
the shipped enemy rewards and difficulty values rather than duplicating them.
The complete deterministic JSON report is the canonical detailed baseline.

## Curves and accounting

The curves describe outcomes, not required builds: **conservative** realizes 70%
of kill income and no optional bonuses, **balanced** realizes 90% plus a 65%
chance of a flawless bonus, and **aggressive** realizes every kill and flawless
bonus. Balanced/aggressive also capture 35%/80% early-call opportunity. The game
currently awards no early-call money, so the report intentionally records `$0`
for that income rather than inventing an economy source.

Kill rewards are rounded per defeated enemy exactly as the game does. Flawless
income uses the shipped per-difficulty bonus and milestone rounding. Purchasing
power is starting cash plus expected income with no purchases deducted. Sell
loss is purchase cost minus the game's floored refund.

## Captured purchasing-power ranges

Ranges are the least- and most-lucrative authored maps after wave 10.

| Difficulty | Conservative | Balanced | Aggressive | Lancer sell loss |
|---|---:|---:|---:|---:|
| Easy | $931.30–$2,369.10 | $1,169.60–$3,018.20 | $1,289–$3,343 | $9 |
| Normal | $928.50–$2,235.40 | $1,166–$2,846.30 | $1,285–$3,152 | $15 |
| Hard | $926.40–$2,108 | $1,163.30–$2,682.50 | $1,282–$2,970 | $24 |

For the balanced curve, wave-one expected kill income spans `$36–$90` on every
difficulty and expected flawless income is `$0.65`; wave-ten kill income spans
`$181.80–$462.60` Easy, `$171–$432` Normal, and `$168.30–$402.30` Hard. Expected
early-call income is `$0` throughout. Full per-wave values are in JSON output.

## Representative affordability

The `$110` Slow plus Lancer entry pair remains affordable before wave 1. Stat-only
upgrade probes use the runtime 0.5625/0.8125/1.125/1.50 curve: a Lancer's first upgrade
is `$34` (`$94` including its base), a Cannon through tier 3 is `$214`, and a
complete Plasma is `$600`. On Hard, complete towers become affordable across
maps in waves 1–2 (Slow), 2–3 (Lancer), 2–4 (Poison), 3–4 (Cannon), 3–5
(Shock), and 4–6 (Plasma). These are independent unspent-purchasing-power probes,
not a build sequence; canonical scenarios contain no specialization or inventory modules.

## Acceptance intent

`economy_bands.json` holds broad bounds, not exact snapshots:

* Normal's `$120` supports the intended two cheapest entry towers while retaining
  six distinct single-tower openings.
* Easy never earns less than Normal and loses only `$9` selling a Lancer versus
  Normal's `$15`, providing recovery room.
* Hard trims later purchasing power and raises that loss to `$24`, but keeps the
  same six base-tower choices—delay without a mandatory opening sequence.

The check fails only when these intents or broad wave-ten envelopes are crossed.
Movement inside a band remains visible in JSON without blocking a change.
