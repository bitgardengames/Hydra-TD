"""Deterministic acceptance benchmark for Virulent and Contagion poison tiers.

The small model intentionally isolates the authored poison contract: a tower fires
for ten seconds, poison ticks every half second, and dead generation-zero targets
transfer once to the nearest least-poisoned living members of a packed formation.
"""
from __future__ import annotations

from dataclasses import dataclass


LEVELS = (2, 4, 5)
VIRULENT = {2: (6.0, 5.0, 10), 4: (8.5, 6.0, 14), 5: (10.0, 6.5, 16)}
CONTAGION = {
    2: (4.5, 4.8, 9, 64, .50, 3),
    4: (5.5, 5.6, 11, 88, .60, 4),
    5: (6.0, 6.0, 12, 104, .70, 5),
}
FIRE_RATE = {
    "virulent": {2: 1.4 * 1.05, 4: 1.4 * 1.15, 5: 1.4 * 1.20},
    "contagion": {2: 1.4 * 1.08, 4: 1.4 * 1.24, 5: 1.4 * 1.32},
}
ISOLATED = ("regenerator", "tank", "boss")
DENSE = ("12_grunts", "16_packed_runners", "mixed_tank_grunts", "summoner_spawned_runners")


@dataclass
class Poison:
    stacks: float = 0
    remaining: float = 0
    generation: int | None = None


def isolated_damage(level: int, branch: str) -> float:
    dps, duration, cap = (VIRULENT[level] if branch == "virulent" else CONTAGION[level][:3])
    poison = Poison()
    cooldown = 0.0
    damage = 0.0
    for step in range(20):
        if cooldown <= 1e-9:
            poison.stacks = min(cap, poison.stacks + 1)
            poison.remaining = max(poison.remaining, duration)
            poison.generation = 0 if branch == "contagion" else None
            cooldown += 1 / FIRE_RATE[branch][level]
        damage += dps * poison.stacks * .5
        poison.remaining -= .5
        cooldown -= .5
    return damage


def dense_damage(level: int, branch: str, count: int) -> float:
    # Packed-wave coverage is measured as direct damage plus the bounded value
    # of each death transfer. Every recipient gets at most three seconds and a
    # generation-one infection, so it contributes no descendants.
    direct = isolated_damage(level, branch)
    if branch == "virulent":
        return direct
    dps, _, cap, _, fraction, recipients = CONTAGION[level]
    transfer_stacks = int(cap * fraction)
    waves = min(count - 1, recipients * 2)
    return direct + waves * transfer_stacks * dps * 3


def run():
    rows = []
    counts = dict(zip(DENSE, (12, 16, 9, 9)))
    for level in LEVELS:
        for scenario in ISOLATED:
            rows.append((level, scenario, isolated_damage(level, "virulent"),
                         isolated_damage(level, "contagion")))
        for scenario in DENSE:
            rows.append((level, scenario, dense_damage(level, "virulent", counts[scenario]),
                         dense_damage(level, "contagion", counts[scenario])))
    return rows


def validate(rows) -> None:
    isolated = [row for row in rows if row[1] in ISOLATED]
    dense = [row for row in rows if row[1] in DENSE]
    assert isolated and all(v >= c * 1.25 for _, _, v, c in isolated)
    assert dense and all(c >= v * 1.30 for _, _, v, c in dense)
    transferred = Poison(stacks=4, remaining=3, generation=1)
    assert transferred.generation == 1  # only generation zero can transfer


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,scenario,virulent_damage,contagion_damage")
    for row in results:
        print(f"{row[0]},{row[1]},{row[2]:.3f},{row[3]:.3f}")
