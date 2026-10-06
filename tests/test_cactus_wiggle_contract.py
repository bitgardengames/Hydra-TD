"""Source-level coverage for the cactus idle wiggle (does not require LÖVE)."""

from pathlib import Path


ROOT = Path(__file__).parents[1]


def _source():
    return (ROOT / "world/scatter_cactus.lua").read_text()


def test_each_cactus_gesture_contains_two_wiggles():
    source = _source()

    assert "local WIGGLES_PER_GESTURE = 2" in source
    assert "(localTime / duration) * WIGGLES_PER_GESTURE" in source


def test_wiggles_reuse_the_rare_idle_interval():
    source = _source()

    assert "local MIN_IDLE_INTERVAL = 5.5" in source
    assert "local IDLE_INTERVAL_VARIANCE = 4.0" in source
    assert "localTime = ((presentationTime or 0) + (cactus.idlePhase or 0)) % interval" in source
