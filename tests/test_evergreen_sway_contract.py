"""Source-level coverage for the evergreen foliage sway (does not require LÖVE)."""

from pathlib import Path


ROOT = Path(__file__).parents[1]


def _evergreen_branch():
    source = (ROOT / "world/scatter_trees.lua").read_text()
    return source[source.index('elseif t.shape == "evergreen" then') :]


def test_evergreen_sway_translates_foliage_without_rotating_it():
    evergreen = _evergreen_branch()

    assert "local swayX = math.sin(" in evergreen
    assert "lg.translate(swayX, 0)" in evergreen
    assert "lg.rotate" not in evergreen


def test_evergreen_tiers_keep_per_tree_and_vertical_phase_offsets():
    evergreen = _evergreen_branch()

    assert "(t.swayPhase or 0)" in evergreen
    assert "(tier - 1) * EVERGREEN_TIER_PHASE" in evergreen
    assert "EVERGREEN_TIER_SWAY[tier]" in evergreen
