"""Contracts for the split module definition catalog."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_DIR = ROOT / "systems" / "module_defs"
EXPECTED_IDS = set("""aoe_damage apply_poison apply_slow beam_conversion cannon_aftershock
cannon_carpet_fire cannon_cluster cannon_cluster_payload cannon_frontline_burst cannon_long_fuse
cannon_mega_shell cannon_rapid_mortar cannon_seige cannon_shockwave cannon_siege_shells chain_fork
chain_hit chaos_bounce explode_on_hit growing_projectile infect_spread lancer_arc_lance
lancer_focus_fire lancer_opening_strike lancer_overdrive lancer_rail_lance lancer_ricochet
lancer_sustained_barrage lancer_volley move_boomerang move_linear move_spiral move_wave orbit_shot
pierce plasma_boomerang_shot plasma_focused_core plasma_growing_mass plasma_lance plasma_lane_sweep
plasma_spiral_drive plasma_supernova plasma_thermal_tracking plasma_unstable_core plasma_vortex
poison_blight poison_corrupt_strong poison_cull_weak poison_hemotoxin poison_neurotoxin
poison_pandemic poison_plague poison_venom_burst shock_boss_focus shock_conductor shock_crowd_search
shock_forked_arc shock_meltdown shock_overcharge shock_overload shock_static_surge shock_storm
shock_storm_coil shock_thunderstorm slow_absolute_zero slow_black_ice slow_cold_snap slow_frost_aura
slow_frost_nova slow_frost_shards slow_glacial_barrage slow_glacier_core slow_hailstorm
slow_lead_freeze slow_permafrost slow_shatter slow_shatterburst slow_snowball slow_wide_chill
spawn_orbitals split_on_hit static_field suspend_shot target_farthest_progress
target_farthest_range target_high_hp target_low_hp tick_damage""".split())
EXPECTED_ALIASES = {
    "slow_permafrost": "slow_frost_shards", "slow_frost_nova": "slow_shatter",
    "slow_shatterburst": "slow_snowball", "slow_cold_snap": "slow_lead_freeze",
    "slow_black_ice": "slow_wide_chill", "lancer_arc_lance": "lancer_focus_fire",
    "cannon_seige": "cannon_siege_shells", "cannon_cluster": "cannon_cluster_payload",
    "cannon_aftershock": "cannon_shockwave", "shock_storm": "shock_storm_coil",
    "shock_conductor": "shock_forked_arc", "shock_overload": "shock_overcharge",
    "plasma_lance": "plasma_focused_core", "plasma_vortex": "plasma_spiral_drive",
}


def sources():
    return {path.name: path.read_text() for path in CATALOG_DIR.glob("*.lua")}


def test_registered_id_set_and_required_metadata():
    files = sources()
    declarations = []
    for name in ("movement.lua", "output.lua", "status.lua", "tower_specializations.lua"):
        declarations.extend(re.findall(r'^(?:add|addSpec)\("([^"]+)"', files[name], re.MULTILINE))
    declarations.extend(EXPECTED_ALIASES)
    assert set(declarations) == EXPECTED_IDS
    assert len(declarations) == len(set(declarations)), "catalog files declare a duplicate module id"

    ordinary = "\n".join(files[name] for name in ("movement.lua", "output.lua", "status.lua"))
    for module_id in set(declarations) - set(EXPECTED_ALIASES):
        if module_id not in re.findall(r'^add\("([^"]+)"', ordinary, re.MULTILINE):
            continue  # addSpec supplies both localization keys positionally.
        start = ordinary.index(f'add("{module_id}"')
        next_entry = ordinary.find("\nadd(\"", start + 1)
        entry = ordinary[start: next_entry if next_entry >= 0 else len(ordinary)]
        assert "nameKey =" in entry and "descKey =" in entry


def test_specializations_capture_behavior_roles():
    helper = sources()["helpers.lua"]
    assert "ProjectileBehaviorRegistry.getRole(behavior.id)" in helper
    assert "replaceBehaviorByRole(op.role" in helper
    specs = sources()["tower_specializations.lua"]
    assert len(re.findall(r'^addSpec\(', specs, re.MULTILINE)) == 43
    assert not re.search(r'^add\(', specs, re.MULTILINE)


def test_legacy_alias_contract_and_duplicate_guard():
    compatibility = sources()["compatibility.lua"]
    aliases = dict(re.findall(r'^\s+(\w+) = "([^"]+)",$', compatibility, re.MULTILINE))
    assert aliases == EXPECTED_ALIASES
    assert 'legacyAliasFor = targetId' in compatibility
    assert 'registry[targetId].apply(ctx)' in compatibility
    assert 'assert(self.registry[id] == nil, "duplicate module id: " .. id)' in sources()["helpers.lua"]
