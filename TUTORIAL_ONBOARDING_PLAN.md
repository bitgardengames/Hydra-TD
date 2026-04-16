# Tutorial / Onboarding Recommendation

## Short answer
Yes—add onboarding, but make it **adaptive and skippable** so it helps new players without annoying experienced players.

---

## Recommended approach: "Hybrid, low-friction tutorial"

Use both ideas, but with strict guardrails:

1. **A 60–90 second micro-scenario** (only for first launch, Easy pacing)
   - Goal: let players place one tower, see it fire, and feel success immediately.
   - Keep it constrained to one clear placement prompt and one wave.
   - Allow **Skip** at any moment.

2. **Contextual tips in first normal run**
   - Show only when relevant (first gold spend, first leak, first upgrade opportunity).
   - Hard cap: at most 1 tip at a time, and no more than 3–4 total in the first run.
   - Every tip has: **Dismiss**, **Don't show again**, and optional keybind reminder.

This gives you confidence-building for new players while minimizing UI noise.

---

## Why this is likely best

- **Custom scenario only** can feel patronizing if forced.
- **Tips only** can be too abstract if players haven't had a successful first action.
- Hybrid solves both:
  - scenario creates immediate competence,
  - tips handle edge cases without blocking play.

---

## Intrusion-prevention rules (important)

- Never block core input once the first tower is placed.
- No modal walls except one optional "Welcome" chooser.
- Respect demonstrated skill:
  - if player places quickly and survives early wave, suppress beginner tips.
- Persist preferences account-wide / profile-wide:
  - `tutorial_completed`
  - `tips_enabled`
  - `expert_mode` (auto-enabled after a strong first win or manually toggled)

---

## Suggested first-time flow

1. **First launch gate (single lightweight prompt)**
   - "New to Hydra TD?"
   - Buttons:
     - `Quick 1-minute tutorial` (recommended)
     - `Jump straight in`

2. **If tutorial chosen**
   - Script:
     1) highlight one valid tile
     2) "Place an Arrow Tower here"
     3) spawn tiny wave
     4) celebrate result + "You're ready"
   - Then route to normal game.

3. **First normal game**
   - Enable contextual tips.
   - Auto-reduce tip frequency if player performs well.

4. **After first victory or 2-3 runs**
   - Prompt once: "Keep gameplay tips on?"
   - default to Off for high-performing players.

---

## UX copy principles

- Keep text short and action-first.
- Prefer verbs and expected outcome:
  - "Place a tower to cover this bend."
  - "Upgrade now to handle armored enemies."
- Avoid jargon in first 5 minutes.

---

## Implementation shape (minimal technical plan)

- Add onboarding state machine:
  - `offering_tutorial`
  - `micro_tutorial`
  - `first_run_tips`
  - `complete`
- Add telemetry events:
  - tutorial start/skip/complete
  - tip shown/dismissed
  - early churn (quit before wave 3)
- Add settings:
  - `Enable gameplay tips` (default on for new profile)
  - `Replay tutorial`

---

## Success metrics to validate

- Increase in first-session completion of wave 5.
- Decrease in first-session quits before first tower placement.
- Low "tips disabled in <2 minutes" rate (proxy for annoyance).
- No retention drop among experienced players.

---

## Practical recommendation

Ship in two phases:

1. **Phase 1 (fast):** contextual tips + settings toggles + skip everywhere.
2. **Phase 2:** add optional 1-minute micro-scenario if first-session confusion remains high.

This keeps scope controlled while preserving your "not intrusive" goal.
