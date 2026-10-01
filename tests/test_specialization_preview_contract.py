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
        "marksman",
        "rupture",
        "deep_freeze",
        "cold_field",
        "virulent",
        "contagion",
        "siege",
        "bombardment",
        "capacitor",
        "forked_lightning",
        "accelerator",
        "overcharged",
    }
    assert branch_ids <= tower_ids
    assert preview_ids == branch_ids


def test_preview_uses_real_gameplay_sandbox():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    assert 'require("world.gameplay_sandbox")' in preview
    for system in (
        "Enemies.updateEnemies",
        "Towers.updateTowers",
        "Projectiles.update",
        "Effects.update",
    ):
        assert system in sandbox
    assert "drawProjectile" not in preview
    assert "drawEffect" not in preview


def test_preview_tower_uses_the_game_world_shadow_renderer():
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    renderer = (ROOT / "render/tower_renderer.lua").read_text()
    assert "TowerRenderer.drawTowerShadow(tower.x, tower.y)" in sandbox
    assert "drawTowerShadow(cx, groundY)" in renderer
    assert "drawTowerShadow = drawTowerShadow" in renderer


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


def test_preview_uses_grid_authored_paths_and_the_gameplay_path_renderer():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    assert 'require("render.draw_world")' in preview
    assert "DrawWorld.drawPath(map)" in preview
    assert "local lane = {{1,3},{8,3}}" in preview
    assert "local bend = {{1,2},{5,2},{5,5},{8,5}}" in preview
    assert "Map.createRenderContext" in sandbox
    assert "drawPathGeometry" not in preview


def test_rupture_and_cold_field_previews_use_the_bend_composition():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    for branch in ("rupture", "cold_field"):
        definition = re.search(rf"^\t{branch}=\{{([^\n]+)", preview, re.M).group(1)
        assert "path=bend" in definition
        assert "camera=bendCamera" in definition
        assert 'tower={kind="' in definition

    rupture = re.search(r"^\trupture=\{([^\n]+)", preview, re.M).group(1)
    cold_field = re.search(r"^\tcold_field=\{([^\n]+)", preview, re.M).group(1)
    assert "x=6,y=2" in rupture
    assert "x=4,y=3" in cold_field


def test_preview_composition_uses_real_grid_placement_and_world_distances():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    towers = re.findall(r'tower=\{kind="[^"]+",x=(\d+),y=(\d+)\}', preview)
    assert towers
    assert all((int(x), int(y)) in {(4, 3), (5, 2), (6, 2)} for x, y in towers)
    assert "*TILE" in preview
    assert "lg.scale(zoom)" in preview


def test_specialization_cards_prioritize_preview_area_without_extra_height():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    assert "Util.clamp(availableCardW, 256, 336)" in picker
    assert "Util.clamp(sh * 0.40, 312, 350)" in picker
    assert "math.min(156, drawH * 0.46)" in picker


def test_specialization_cards_do_not_show_a_specialize_price_cta():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    strings = (ROOT / "languages/enUS.lua").read_text()
    assert "specializeCta" not in picker
    assert "specializeCta" not in strings


def test_specialization_preview_uses_the_upgrade_name_border_and_cards_do_not_lift():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    preview_border = re.search(
        r'lg\.setColor\(borderR, borderG, borderB, alpha\)\s*'
        r'lg\.rectangle\("fill", previewX - outlineW, previewY - outlineW,\s*'
        r'previewW \+ outlineW \* 2, previewH \+ outlineW \* 2, outerSmallRadius\)',
        picker,
    )
    assert preview_border
    assert "- c.hover * 4" not in picker


def test_preview_background_uses_the_default_biome_grass_palette():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    assert "lg.setColor(map.biome.terrain.grass)" in preview
    assert "DrawWorld.drawPath(map)" in preview


def test_preview_camera_is_uniform_and_objects_have_no_preview_scale():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    assert "lg.scale(cw/" not in preview
    assert "lg.scale(zoom)" in preview
    assert "function Preview.resolveCamera" in preview
    for duplicated_scale in (
        "PREVIEW_PATH_WIDTH",
        "PREVIEW_ENEMY_SIZE",
        "PREVIEW_TOWER_SCALE",
        "PREVIEW_PROJECTILE_SCALE",
    ):
        assert duplicated_scale not in preview


def test_authored_specialization_cameras_use_one_x_zoom():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    camera_zooms = re.findall(r"local (?:straight|bend)Camera = \{[^}]*zoom=([\d.]+)\}", preview)
    assert camera_zooms == ["1", "1"]


def test_sandbox_supports_authored_real_enemy_staging():
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    for field in (
        "initialDistance",
        "spawnDistance",
        "spawnTime",
        "spacing",
        "count",
        "healthOverride",
        "speedOverride",
    ):
        assert field in sandbox


def test_preview_targeting_cache_is_isolated_between_cards():
    sandbox = (ROOT / "world/gameplay_sandbox.lua").read_text()
    assert 'require("world.targeting")' in sandbox
    assert sandbox.count("Targeting.clearFrameCache()") >= 2


def test_spatial_clear_invalidates_entity_membership_before_a_rebuild():
    spatial = (ROOT / "world/spatial_grid.lua").read_text()
    clear_body = spatial[
        spatial.index("function Spatial.clear()") : spatial.index("function Spatial.beginFrame()")
    ]
    for field in ("cell", "cellIndex", "cellX", "cellY"):
        assert f"enemy.{field} = nil" in clear_body
