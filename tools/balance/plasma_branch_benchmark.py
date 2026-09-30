"""Deterministic geometry benchmark for Accelerator and Overcharged Plasma."""

from __future__ import annotations

from dataclasses import dataclass

LEVELS = (2, 4, 5)
BASE_DAMAGE, BASE_FIRE_RATE, BASE_COST = 4.0, 0.75, 120
UPGRADE_COSTS = (150, 180, 210, 240)

# damage, fire rate, speed, travel distance, tick radius, tick interval
ACCELERATOR = {
    2: (1.35, 1.05, 140, 390, 14, 0.14),
    3: (1.65, 1.10, 155, 450, 14, 0.14),
    4: (2.05, 1.15, 175, 520, 13, 0.14),
    5: (2.55, 1.20, 200, 600, 12, 0.14),
}
OVERCHARGED = {
    2: (1.18, 1.06, 112, 340, 20, 0.13),
    3: (1.40, 1.13, 106, 350, 24, 0.12),
    4: (1.68, 1.20, 100, 360, 28, 0.11),
    5: (2.00, 1.28, 94, 370, 32, 0.10),
}


@dataclass(frozen=True)
class Fixture:
    name: str
    enemy_hp: int = 1_000_000
    enemy_count: int = 12
    exposure_distance: int = 600


FIXTURES = (
    Fixture("straight_lane"),
    Fixture("ninety_degree_bend"),
    Fixture("crossing"),
    Fixture("loop"),
)


def tower_cost(level: int) -> int:
    return BASE_COST + sum(UPGRADE_COSTS[: level - 1])


def geometry_contact(fixture: Fixture, stats: tuple[float, ...]) -> float:
    """Stable pixel-tick proxy: distance wins lanes; area wins local features."""
    _, _, _, distance, radius, tick = stats
    if fixture.name == "straight_lane":
        return min(distance, fixture.exposure_distance) / tick
    if fixture.name == "ninety_degree_bend":
        return radius * radius * 1.35 / tick
    if fixture.name == "crossing":
        return radius * radius * 1.60 / tick
    return (distance * 0.45 + radius * radius * 0.55) / tick


def damage(level: int, branch: str, fixture: Fixture, towers: float = 1) -> float:
    stats = ACCELERATOR[level] if branch == "accelerator" else OVERCHARGED[level]
    damage_mult, fire_mult, *_ = stats
    return (
        towers
        * fixture.enemy_count
        * BASE_DAMAGE
        * damage_mult
        * BASE_FIRE_RATE
        * fire_mult
        * geometry_contact(fixture, stats)
    )


def equal_cost_lower_group(level: int, branch: str, fixture: Fixture) -> tuple[int, float, float]:
    """Compare a lower tier at the exact same normalized budget."""
    lower = 1 if level == 2 else (2 if level == 4 else 3)
    if lower == 1:
        base_stats = (1, 1, 120, 330, 16, 0.14)
        lower_damage = (
            fixture.enemy_count
            * BASE_DAMAGE
            * BASE_FIRE_RATE
            * geometry_contact(fixture, base_stats)
        )
    else:
        lower_damage = damage(lower, branch, fixture)
    equivalents = tower_cost(level) / tower_cost(lower)
    return lower, equivalents, lower_damage * equivalents


def run() -> list[dict[str, float | int | str]]:
    rows = []
    for level in LEVELS:
        for fixture in FIXTURES:
            row: dict[str, float | int | str] = {
                "level": level,
                "geometry": fixture.name,
                "accelerator": damage(level, "accelerator", fixture),
                "overcharged": damage(level, "overcharged", fixture),
            }
            for branch in ("accelerator", "overcharged"):
                lower, count, output = equal_cost_lower_group(level, branch, fixture)
                row[f"{branch}_lower_level"] = lower
                row[f"{branch}_lower_count"] = count
                row[f"{branch}_lower_damage"] = output
            rows.append(row)
    return rows


def validate(rows: list[dict[str, float | int | str]]) -> None:
    assert len({(f.enemy_hp, f.enemy_count, f.exposure_distance) for f in FIXTURES}) == 1
    for row in rows:
        accelerator, overcharged = float(row["accelerator"]), float(row["overcharged"])
        if row["geometry"] == "straight_lane":
            assert accelerator >= overcharged * 1.15
        elif row["geometry"] in ("ninety_degree_bend", "crossing"):
            assert overcharged >= accelerator * 1.20
    winners = {
        "accelerator" if float(row["accelerator"]) > float(row["overcharged"]) else "overcharged"
        for row in rows
    }
    assert winners == {"accelerator", "overcharged"}


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,geometry,accelerator,overcharged")
    for result in results:
        print(
            f'{result["level"]},{result["geometry"]},'
            f'{float(result["accelerator"]):.3f},{float(result["overcharged"]):.3f}'
        )
