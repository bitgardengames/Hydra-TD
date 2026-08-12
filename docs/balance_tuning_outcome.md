# Intended-challenge balance baseline

This baseline was produced with the deterministic balance suite and the
`intended_challenge` target profile. The optimizer evaluated all allow-listed
combat and economy categories: tower cost, damage, and fire rate; upgrade costs;
enemy HP and rewards; difficulty durability, rewards, and starting cash; and
campaign group counts and spacing. Candidates were retained only when the
aggregate combat, pacing, economy, campaign-challenge, ability/interaction, and
polish gates passed.

## Applied outcome

The simulation increased the Shieldbearer reward from **$12 to $13** and the
Warcaller reward from **$9 to $10**. Their durability and mechanics are unchanged:
players who select the intended Shock and priority-targeting counters now recover
enough of their investment to keep pace with later mixed waves. This follows the
prior baseline's Lancer fire-rate adjustment and Regenerator HP reduction while
preserving every tower's specialist role.

The economy fixture's wave-ten ceilings now include the simulated late-campaign
reward outcome. They remain regression bands rather than targets: Easy allows up
to $2,650 balanced / $2,100 conservative purchasing power, Normal $2,500 /
$1,950, and Hard $2,400 / $1,900.

The resulting aggregate profile is:

| Metric | Previous baseline | Tuned baseline | Authored target |
|:--|--:|--:|:--|
| Required / affordable DPS | 6,500 bp | 6,412 bp | 4,200–9,000 bp |
| Wave-income coverage | 4,421 bp | 4,532 bp | 3,500–8,000 bp |
| Threat per reward dollar | 5 | 5 | 3–5 |
| Specialist role performance | 10,000 bp | 10,000 bp | 9,000–10,000 bp |
| Leak allowance | 2,556 bp | 2,467 bp | 500–2,200 bp |
| First-upgrade timing | wave 1 | wave 2 | waves 2–5 |
| Wave-to-wave growth | 12,000 bp | 12,000 bp | 10,100–13,500 bp |

The upgrade timing metric now measures the complete purchase of a representative
tower **and** its first upgrade, rather than comparing cash only with the upgrade
fee. This makes the metric correspond to what a player must actually spend and
places the baseline inside the authored wave 2–5 window.

Leak allowance remains slightly outside the aspirational profile. Further
single-coordinate proposals did not safely improve the weighted result under the
current acceptance constraints. That gap should drive playtesting and a future
coupled-design pass rather than unvalidated stat churn. The simulation is a
repeatable baseline and regression guard; it is not proof that placement choices,
learning curve, or moment-to-moment play are fun.

## Reproduction

```sh
python3 tools/balance/recommend.py --recommend --profile intended_challenge --output balance-recommendation.json
python3 tools/balance/check.py
```

Regenerate checked-in evidence after an accepted value change:

```sh
python3 tools/balance/challenge_fixtures.py --write-docs
python3 tools/balance/interaction_fixtures.py --write
```
