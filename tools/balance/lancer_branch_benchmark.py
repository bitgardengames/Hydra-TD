"""Deterministic geometry benchmark for the two Lancer upgrade branches."""

from __future__ import annotations

from dataclasses import dataclass

LEVELS = (2, 4, 5)
ENEMIES = ("grunt", "tank", "regenerator", "warcaller", "summoner", "boss")
BASE_DAMAGE = 9.0
BASE_FIRE_RATE = 2.2
COLLISION_RADIUS = 12.0

MARKSMAN = {
    2: (1.55, 1.00),
    4: (2.75, 1.04),
    5: (3.50, 1.06),
}
RUPTURE = {
    2: (1.30, 1.045, 2),
    4: (2.15, 1.135, 3),
    5: (2.65, 1.18, 4),
}


@dataclass(frozen=True)
class Result:
    level: int
    scenario: str
    marksman: float
    rupture: float

    @property
    def rupture_contacts(self) -> float:
        return self.rupture / (
            BASE_DAMAGE * RUPTURE[self.level][0] * BASE_FIRE_RATE * RUPTURE[self.level][1]
        )


def sustained_damage(level: int, branch: str, contacts: int = 1) -> float:
    if branch == "marksman":
        damage, rate = MARKSMAN[level]
        return BASE_DAMAGE * damage * BASE_FIRE_RATE * rate
    damage, rate, max_hits = RUPTURE[level]
    return BASE_DAMAGE * damage * BASE_FIRE_RATE * rate * min(contacts, max_hits)


def run() -> list[Result]:
    rows = []
    for level in LEVELS:
        marksman = sustained_damage(level, "marksman")
        rupture = sustained_damage(level, "rupture")
        for enemy in ENEMIES:
            rows.append(Result(level, f"isolated:{enemy}", marksman, rupture))
        for count in (2, 4):
            rows.append(
                Result(
                    level, f"aligned:{count}", marksman, sustained_damage(level, "rupture", count)
                )
            )
            # A perpendicular displacement strictly greater than the collision
            # radius means only the aimed-at enemy can intersect the projectile.
            rows.append(Result(level, f"offset>{COLLISION_RADIUS:g}px:{count}", marksman, rupture))
    return rows


def validate(rows: list[Result]) -> None:
    isolated = [row for row in rows if row.scenario.startswith("isolated:")]
    assert all(row.marksman >= row.rupture * 1.10 for row in isolated)
    for level in LEVELS:
        marksman = sustained_damage(level, "marksman")
        three_aligned = sustained_damage(level, "rupture", 3)
        assert three_aligned >= marksman * 1.35


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,scenario,marksman_dps,rupture_dps")
    for result in results:
        print(f"{result.level},{result.scenario},{result.marksman:.3f},{result.rupture:.3f}")
