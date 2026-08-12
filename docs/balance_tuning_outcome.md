# Intended-challenge balance baseline

This baseline was produced with the deterministic balance suite and the
`intended_challenge` target profile. The optimizer evaluated all allow-listed
combat and economy categories (tower cost, damage, and fire rate; upgrade cost
multipliers; enemy HP and rewards; difficulty durability, rewards, and starting
cash; and campaign group counts and spacing). Candidate values were retained
only when the aggregate combat, pacing, economy, campaign-challenge,
ability/interaction, and polish gates all passed.

## Applied outcome

The Regenerator's base HP is **37**, down from 40. This reduces the attrition
spike while preserving Poison as its best counter and leaving its regeneration,
reward, speed, and damage modifiers unchanged. No tower, upgrade, wave,
difficulty, or other enemy value produced a safer improvement under the current
constraints, so those shipped values remain the baseline rather than being
changed merely to make every category differ.

The resulting aggregate profile is:

| Metric | Before | Baseline | Authored target |
|:--|--:|--:|:--|
| Required / affordable DPS | 6,549 bp | 6,500 bp | 4,200–9,000 bp |
| Wave-income coverage | 4,384 bp | 4,421 bp | 3,500–8,000 bp |
| Threat per reward dollar | 5 | 5 | 3–5 |
| Specialist role performance | 10,000 bp | 10,000 bp | 9,000–10,000 bp |
| Leak allowance | 2,644 bp | 2,556 bp | 500–2,200 bp |
| First-upgrade timing | wave 1 | wave 1 | waves 2–5 |
| Wave-to-wave growth | 12,000 bp | 12,000 bp | 10,100–13,500 bp |

Leak allowance and upgrade timing remain outside the aspirational profile.
Further automated proposals either failed to improve the weighted result or
violated a shipped acceptance gate. Those gaps should drive playtesting and a
future coupled-design pass, not broader unvalidated stat churn. In particular,
the simulation is a repeatable baseline and regression guard; it is not proof
that placement decisions, learning curve, or moment-to-moment play are fun.

## Reproduction

```sh
python3 tools/balance/recommend.py --recommend --profile intended_challenge --output balance-recommendation.json
python3 tools/balance/check.py
```

Regenerate the checked-in evidence after an accepted value change:

```sh
python3 tools/balance/challenge_fixtures.py --write-docs
python3 tools/balance/interaction_fixtures.py --write
```
