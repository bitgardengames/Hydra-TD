"""Deterministic 12-second benchmark for Shock's two specializations."""
from __future__ import annotations

from dataclasses import dataclass


LEVELS = (2, 4, 5)
BASE_DAMAGE = 8.0
BASE_FIRE_RATE = 1.1
DURATION = 12.0

CAPACITOR = {
    2: (1.45, 1.02, 2, 0.82, 4, 1.00),
    4: (2.35, 1.08, 2, 0.84, 4, 1.10),
    5: (3.00, 1.12, 2, 0.85, 3, 1.20),
}
FORKED = {
    2: (1.20, 1.06, 5, 0.88),
    4: (1.75, 1.18, 7, 0.90),
    5: (2.15, 1.24, 8, 0.92),
}

SCENARIOS = {
    "isolated:tank": 1,
    "isolated:warcaller": 1,
    "isolated:boss": 1,
    "spaced:8_grunts": 8,
    "packed:16_runners": 16,
    "supported:warcaller_group": 8,
}


@dataclass(frozen=True)
class Result:
    level: int
    scenario: str
    targets: int
    capacitor_damage: float
    forked_damage: float
    capacitor_charges: int


def attack_count(rate_mult: float) -> int:
    # A ready tower attacks at t=0 and then at each complete interval.
    return int(DURATION * BASE_FIRE_RATE * rate_mult) + 1


def chain_multiplier(targets: int, jumps: int, falloff: float) -> float:
    return sum(falloff ** contact for contact in range(min(targets, jumps + 1)))


def capacitor_result(level: int, targets: int) -> tuple[float, int]:
    damage, rate, jumps, falloff, threshold, discharge = CAPACITOR[level]
    attacks = attack_count(rate)
    per_attack = BASE_DAMAGE * damage * chain_multiplier(targets, jumps, falloff)
    discharges = attacks // threshold
    total = attacks * per_attack + discharges * BASE_DAMAGE * damage * discharge
    return total, attacks


def forked_result(level: int, targets: int) -> float:
    damage, rate, jumps, falloff = FORKED[level]
    return (attack_count(rate) * BASE_DAMAGE * damage
            * chain_multiplier(targets, jumps, falloff))


def run() -> list[Result]:
    rows = []
    for level in LEVELS:
        for scenario, targets in SCENARIOS.items():
            capacitor_damage, charges = capacitor_result(level, targets)
            rows.append(Result(level, scenario, targets, capacitor_damage,
                               forked_result(level, targets), charges))
    return rows


def validate(rows: list[Result]) -> None:
    for row in rows:
        if row.targets == 1:
            assert row.capacitor_damage >= row.forked_damage * 1.15
        if row.targets >= 6:
            assert row.forked_damage >= row.capacitor_damage * 1.30
    for level in LEVELS:
        one = capacitor_result(level, 1)[1]
        eight = capacitor_result(level, 8)[1]
        assert one == eight


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,scenario,targets,capacitor_damage,forked_damage,capacitor_charges")
    for result in results:
        print(f"{result.level},{result.scenario},{result.targets},"
              f"{result.capacitor_damage:.3f},{result.forked_damage:.3f},"
              f"{result.capacitor_charges}")
