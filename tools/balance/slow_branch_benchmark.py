"""Deterministic movement benchmark for Deep Freeze and Cold Field.

This deliberately models control rather than damage. Shots resolve immediately at a
valid target position; Cold Fields remain at that impact point, so every geometry
fixture measures path exposure instead of accidentally modelling a tower aura.
"""

from __future__ import annotations

from dataclasses import dataclass
from math import hypot

LEVELS = (2, 4, 5)
DT = 0.01
BASE_RATE = 1.2
BASE_RANGE = 4.25 * 48
DIRECT_STRENGTH = 0.45
DIRECT_DURATION = 1.7
DEEP = {
    2: (1.05, 0.18 * 48, 0.58, 1.7 + 0.55),
    4: (1.15, 0.54 * 48, 0.68, 1.7 + 0.55),
    5: (1.20, 0.72 * 48, 0.72, 1.7 + 0.55),
}
FIELD = {
    2: (1.08, 0.14 * 48, 62, 2.4, 0.36),
    4: (1.24, 0.42 * 48, 74, 3.2, 0.42),
    5: (1.32, 0.56 * 48, 82, 3.6, 0.45),
}
PATHS = {
    "straight": ((-300.0, 0.0), (300.0, 0.0)),
    "bend_90": ((-300.0, 0.0), (0.0, 0.0), (0.0, 300.0)),
    "crossing": ((-300.0, -110.0), (180.0, 110.0), (-180.0, 110.0), (300.0, -110.0)),
    "loop": (
        (-280.0, 0.0),
        (-120.0, 0.0),
        (-120.0, 120.0),
        (120.0, 120.0),
        (120.0, -120.0),
        (-120.0, -120.0),
        (-120.0, 0.0),
        (280.0, 0.0),
    ),
}


@dataclass
class Enemy:
    path: tuple[tuple[float, float], ...]
    speed: float
    spawn: float
    segment: int = 0
    progress: float = 0
    slow_factor: float = 1
    slow_until: float = 0
    exit_time: float | None = None

    @property
    def position(self):
        a, b = self.path[self.segment], self.path[self.segment + 1]
        length = hypot(b[0] - a[0], b[1] - a[1])
        part = self.progress / length
        return a[0] + (b[0] - a[0]) * part, a[1] + (b[1] - a[1]) * part

    def move(self, distance):
        while distance > 0 and self.exit_time is None:
            a, b = self.path[self.segment], self.path[self.segment + 1]
            length = hypot(b[0] - a[0], b[1] - a[1])
            step = min(distance, length - self.progress)
            self.progress += step
            distance -= step
            if self.progress >= length - 1e-9:
                self.segment += 1
                self.progress = 0
                if self.segment == len(self.path) - 1:
                    self.exit_time = 0


@dataclass
class Field:
    x: float
    y: float
    radius: float
    strength: float
    expires: float
    next_tick: float


def path_time(path, speed):
    return sum(hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(path, path[1:])) / speed


def simulate(level, branch, path, count, spacing, speed, support=False):
    enemies = [Enemy(path, speed * (1.12 if support else 1), i * spacing) for i in range(count)]
    rate, range_add = (
        (DEEP[level][0], DEEP[level][1]) if branch == "deep_freeze" else FIELD[level][:2]
    )
    cooldown, fields, now = 0.0, [], 0.0
    while any(e.exit_time is None for e in enemies) and now < 180:
        for e in enemies:
            if e.exit_time is not None or now < e.spawn:
                continue
            if now >= e.slow_until:
                e.slow_factor = 1
            e.move(e.speed * e.slow_factor * DT)
            if e.exit_time == 0:
                e.exit_time = now
        # Refreshing uses the shipped strongest-slow/maximum-duration semantics:
        # minimum factor and maximum expiry, never factor multiplication.
        if branch == "cold_field":
            for field in fields:
                if now + 1e-9 >= field.next_tick and now < field.expires:
                    for e in enemies:
                        if e.exit_time is None and now >= e.spawn:
                            x, y = e.position
                            if hypot(x - field.x, y - field.y) <= field.radius:
                                e.slow_factor = min(e.slow_factor, 1 - field.strength)
                                e.slow_until = max(e.slow_until, now + 0.4)
                    field.next_tick += 0.25
            fields[:] = [field for field in fields if now < field.expires]
        cooldown -= DT
        if cooldown <= 0:
            candidates = []
            for e in enemies:
                if e.exit_time is None and now >= e.spawn:
                    x, y = e.position
                    if hypot(x, y) <= BASE_RANGE + range_add:
                        candidates.append(e)
            if candidates:
                target = max(candidates, key=lambda e: (e.segment, e.progress))
                if branch == "deep_freeze":
                    strength, duration = DEEP[level][2:]
                else:
                    strength, duration = (
                        DIRECT_STRENGTH,
                        DIRECT_DURATION + {2: 0.35, 4: 1.05, 5: 1.40}[level],
                    )
                target.slow_factor = min(target.slow_factor, 1 - strength)
                target.slow_until = max(target.slow_until, now + duration)
                if branch == "cold_field":
                    x, y = target.position
                    radius, life, strength = FIELD[level][2:]
                    fields.append(Field(x, y, radius, strength, now + life, now))
                cooldown = 1 / (BASE_RATE * rate)
        now += DT
    baseline = path_time(path, speed * (1.12 if support else 1))
    return sum((e.exit_time - e.spawn) - baseline for e in enemies)


def run():
    rows = []
    scenarios = [
        ("runner", 1, 0.0, 104.0, False),
        ("runner_pack", 8, 0.35, 104.0, False),
        ("warcaller", 1, 0.0, 48.0, False),
        ("warcaller_group", 8, 0.35, 72.0, True),
    ]
    for level in LEVELS:
        for fixture, path in PATHS.items():
            for name, count, spacing, speed, support in scenarios:
                deep = simulate(level, "deep_freeze", path, count, spacing, speed, support)
                field = simulate(level, "cold_field", path, count, spacing, speed, support)
                rows.append((level, fixture, name, deep, field))
    return rows


def validate(rows):
    urgent = [r for r in rows if r[2] == "runner"]
    packs = [r for r in rows if r[2] in ("runner_pack", "warcaller_group")]
    assert urgent and all(deep >= field * 1.20 for _, _, _, deep, field in urgent)
    assert packs and all(field >= deep * 1.30 for _, _, _, deep, field in packs)


if __name__ == "__main__":
    results = run()
    validate(results)
    print("level,fixture,scenario,deep_freeze_delay,cold_field_delay")
    for row in results:
        print(f"{row[0]},{row[1]},{row[2]},{row[3]:.3f},{row[4]:.3f}")
