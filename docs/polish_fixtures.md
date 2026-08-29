# Non-rendered polish fixtures

`tools/balance/polish_report.py` derives refinement signals from shipped Lua
definitions and declarative panel geometry without starting LÖVE or rendering a
frame. Its JSON output is the detailed capture; `polish_bands.json` contains
broad **regression alarms**, not exact snapshots. Normal tuning movement inside
a band remains visible and does not fail CI, matching the intent of the economy
fixtures.

## Timing and authored pressure

Preparation has no authored countdown: it is player-started and therefore has
no finite duration to snapshot. The report instead records this contract and
reports average between-wave downtime as unbounded/non-numeric, and measures
the actionable average recovery delay between sequential authored groups. Live
enemy count depends on map path length, speed, slows, and damage, so “active by
authored wave” uses the pacing fixture's deterministic five-second spawn window.
The broad alarms are **0.25–2.25 seconds** average recovery and **10–24 enemies**
at peak. Every map/wave remains available in JSON for investigation.

## Presentation event budgets

The representative formation contains one continuously engaged tower of each
of the six kinds. Base and tier-five fire rates provide expected projectile
emission rates of **6.5–8.5/s** and **8–11/s**. The base damage-floater alarm is
also **6.5–8.5/s**, assuming one aggregated visible number per attack. Secondary
chain, splash, poison, and repeated-field hits are intentionally excluded: this
is a readable baseline, not a worst-case particle benchmark.

## Ability duration and overlap

Instant abilities correctly report zero duration. Each simultaneous pair's
overlap is the shorter active duration when cast together. Pair overlap alarms
at **0–8.5 seconds** catch accidentally long effects while allowing intentional
burst combinations.

## Preview and HUD fit

The preview report scans every campaign wave and records distinct composition
rows. Counter-hint wrapping uses a conservative dependency-free English
average-glyph model at the default font size. The alarms allow **1–6 rows**
and **1–20 wrapped counter lines**. This deliberately includes the largest
authored preview rather than a hand-built small example.

HUD rectangles are checked at 1280×720, 1280×800, 1920×1080, and 2560×1440.
The representative stress case is the minimum 1280×720 resolution with six
damage-meter rows and all six ability slots. Authored panel bounds must have
**zero overflow pixels**.

## Upgrade timing

The report reuses the balanced economy curve and runtime stat-only upgrade multipliers; specialization is excluded.
For every tower and difficulty it reports the earliest/latest map wave where
unspent purchasing power can afford the first upgrade or the complete final
tier. These are independent affordability probes, never a prescribed build.
On Hard, first upgrades alarm outside waves **0–2** and complete towers outside
waves **2–8**. Observed complete-tower affordability spans waves **1–6** across
tower kinds and maps. This protects useful upgrade feedback cadence without pinning
income to an exact dollar snapshot.

Run the focused gate with:

```sh
python3 tools/balance/polish_report.py --check
```

or all balance gates with `python3 tools/balance/check.py`.
