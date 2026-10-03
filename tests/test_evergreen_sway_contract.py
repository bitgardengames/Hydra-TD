"""Source-level coverage for the evergreen foliage sway (does not require LÖVE)."""

from pathlib import Path


ROOT = Path(__file__).parents[1]


def _evergreen_branch():
    source = (ROOT / "world/scatter_trees.lua").read_text()
    return source[source.index('elseif t.shape == "evergreen" then') :]


def test_evergreen_sway_rotates_each_tier_from_its_base():
    evergreen = _evergreen_branch()

    assert "local sway = math.sin(" in evergreen
    assert "lg.translate(x, ly + h)" in evergreen
    assert "lg.rotate(sway)" in evergreen
    assert "lg.translate(-x, -(ly + h))" in evergreen


def test_evergreen_tiers_keep_per_tree_and_vertical_phase_offsets():
    evergreen = _evergreen_branch()

    assert "(t.swayPhase or 0)" in evergreen
    assert "(tier - 1) * EVERGREEN_TIER_PHASE" in evergreen
    assert "EVERGREEN_TIER_SWAY[tier]" in evergreen


def test_evergreen_sway_increases_from_bottom_to_top():
    source = (ROOT / "world/scatter_trees.lua").read_text()

    assert "local EVERGREEN_TIER_SWAY = {0.43, 0.66, 0.86}" in source
    assert "local tier = layers - i + 1" in _evergreen_branch()
