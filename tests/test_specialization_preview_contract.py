"""Source-level coverage for the preview contract (does not require LÖVE)."""
import re
from pathlib import Path


ROOT = Path(__file__).parents[1]


def _branch_ids(source):
    return set(re.findall(r"\bid\s*=\s*\"([a-z_]+)\"", source))


def test_every_tower_branch_has_an_authored_preview():
    tower_ids = _branch_ids((ROOT / "world/tower_defs.lua").read_text())
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    preview_ids = set(re.findall(r"^\t([a-z_]+)\s*=\{duration=", preview, re.M))
    branch_ids = {
        "marksman", "rupture", "deep_freeze", "cold_field", "virulent", "contagion",
        "siege", "bombardment", "capacitor", "forked_lightning", "accelerator", "overcharged",
    }
    assert branch_ids <= tower_ids
    assert preview_ids == branch_ids


def test_preview_uses_real_gameplay_sandbox():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    assert 'require("world.gameplay_sandbox")' in preview
    for system in ("Enemies.updateEnemies", "Towers.updateTowers", "Projectiles.update", "Effects.update"):
        assert system in sandbox
    assert "drawProjectile" not in preview
    assert "drawEffect" not in preview


def test_picker_lifecycle_owns_preview_updates_and_release():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    assert 'State.modulePicker.mode == "specialization"' in picker
    assert "SpecializationPreview.update(previews[i], dt)" in picker
    assert "SpecializationPreview.release(previews[i])" in picker
    assert picker.index("if not ModulePicker.isActive() then return end") < picker.index(
        "SpecializationPreview.update(previews[i], dt)"
    )


def test_specialization_picker_hides_selected_tower_range_without_extra_bars():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    renderer = (ROOT / "render/tower_renderer.lua").read_text()
    assert 'State.modulePicker.mode == "specialization"' in renderer
    assert "if not choosingSpecialization then" in renderer
    assert renderer.index("if not choosingSpecialization then") < renderer.index(
        'lg.circle("fill", selected.x, selected.y, selected.range)'
    )
    assert "drawBackdropEffects" not in picker


def test_preview_does_not_require_transform_query_api():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    assert "lg.getTransform" not in preview
    assert "lg.replaceTransform" not in preview
    assert 'lg.push("all")' in preview
    assert "lg.pop()" in preview


def test_preview_requests_stencil_buffer_when_setting_render_target():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    canvas_settings = re.search(r"newCanvas\([^\n]+\{([^}]*)}", preview).group(1)
    assert "stencil" not in canvas_settings
    assert re.search(r"\bmsaa\s*=\s*8\b", canvas_settings)
    assert re.search(r"setCanvas\(\{p\.canvas,\s*stencil\s*=\s*true}", preview)
    assert "lg.stencil(drawCanvasClip" in preview


def test_preview_uses_a_straight_lane_and_the_gameplay_path_renderer():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    assert 'require("render.draw_world")' in preview
    assert "DrawWorld.drawPath(map)" in preview
    path = re.search(r"local path = \{\{([^}]+)\},\{([^}]+)\}\}", preview)
    assert path
    assert path.group(1).split(",")[1] == path.group(2).split(",")[1]
    assert "lg.line" not in preview


def test_preview_composition_puts_the_tower_above_the_lowered_lane():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    lane = re.search(r"local path = \{\{[^,]+,([^}]+)\},\{[^,]+,([^}]+)\}\}", preview)
    towers = re.findall(r'tower=\{kind="[^"]+",x=(\d+),y=(\d+)\}', preview)
    assert lane and int(lane.group(1)) == 82
    assert towers
    assert all(132 <= int(x) <= 136 and int(y) == 36 for x, y in towers)


def test_specialization_cards_prioritize_preview_area_without_extra_height():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    assert "Util.clamp(availableCardW, 256, 336)" in picker
    assert "Util.clamp(sh * 0.40, 312, 350)" in picker
    assert "math.min(156, drawH * 0.46)" in picker


def test_preview_background_uses_the_default_biome_grass_palette():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    assert "lg.setColor(map.biome.terrain.grass)" in preview
    assert "lg.circle" not in preview


def test_preview_targeting_cache_is_isolated_between_cards():
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    assert 'require("world.targeting")' in sandbox
    assert sandbox.count("Targeting.clearFrameCache()") >= 2


def test_spatial_clear_invalidates_entity_membership_before_a_rebuild():
    spatial = (ROOT / "world/spatial_grid.lua").read_text()
    clear_body = spatial[spatial.index("function Spatial.clear()"):
                         spatial.index("function Spatial.beginFrame()")]
    for field in ("cell", "cellIndex", "cellX", "cellY"):
        assert f"enemy.{field} = nil" in clear_body
