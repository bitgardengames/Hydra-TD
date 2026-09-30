"""Deterministic damage benchmark for Cannon's Siege and Bombardment tiers."""

from __future__ import annotations

from dataclasses import dataclass

LEVELS = (2, 4, 5)
BASE_DAMAGE = 14.0
BASE_FIRE_RATE = 0.7
DURATION = 12.0
IMPACT_DISTANCES = (0, 30, 44, 56, 70, 84)

SIEGE = {
    2: (1.80, 1.02, 50, 0.68),
    4: (2.90, 1.06, 54, 0.70),
    5: (3.55, 1.08, 56, 0.72),
}
BOMBARDMENT = {
    2: (1.35, 1.04, 64, 0.72),
    4: (1.95, 1.12, 78, 0.76),
    5: (2.30, 1.16, 84, 0.78),
}

# Counts are deliberately explicit. Runner timing is part of the fixture rather
# than being treated as a permanently packed group.
SCENARIOS = {
    "isolated:tank": (0,),
    "isolated:warcaller": (0,),
    "isolated:boss": (0,),
    "runners:16@0.32s": (0, 30, 44, 56, 70, 84),
    "group:normal_grunts": (0, 30, 44, 56, 70, 84),
    "group:mixed_tank_grunts": (0, 30, 44, 56, 70, 84),
}


@dataclass(frozen=True)
class Result:
    level: int
    scenario: str
    siege_damage: float
    bombardment_damage: float


def attack_count(rate_multiplier: float) -> int:
    return int(DURATION * BASE_FIRE_RATE * rate_multiplier) + 1


def blast_multiplier(distance: float, radius: float, falloff: float) -> float:
    if distance > radius:
        return 0.0
    return falloff + (1 - falloff) * (1 - distance * distance / (radius * radius))


def damage(level: int, branch: str, distances: tuple[float, ...]) -> float:
    damage_mult, fire_mult, radius, falloff = (
        SIEGE[level] if branch == "siege" else BOMBARDMENT[level]
    )
    coverage = sum(blast_multiplier(d, radius, falloff) for d in distances)
    return attack_count(fire_mult) * BASE_DAMAGE * damage_mult * coverage


def run() -> list[Result]:
    return [
        Result(
            level,
            scenario,
            damage(level, "siege", distances),
            damage(level, "bombardment", distances),
        )
        for level in LEVELS
        for scenario, distances in SCENARIOS.items()
    ]


def validate(rows: list[Result]) -> None:
    isolated = [row for row in rows if row.scenario.startswith("isolated:")]
    assert isolated and all(row.siege_damage >= row.bombardment_damage * 1.30 for row in isolated)
    # Three ordinary targets in the part of Bombardment's blast beyond Siege's
    # radius are enough to establish the crowd-damage crossover.
    for level in LEVELS:
        outer = (56, 70, 84)
        assert damage(level, "bombardment", outer) > damage(level, "siege", outer)
        crowded = SCENARIOS["group:normal_grunts"]
        assert damage(level, "bombardment", crowded) > damage(level, "siege", crowded)


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,scenario,siege_damage,bombardment_damage")
    for result in results:
        print(
            f"{result.level},{result.scenario},{result.siege_damage:.3f},"
            f"{result.bombardment_damage:.3f}"
        )
