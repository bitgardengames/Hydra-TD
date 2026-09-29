"""Source-level coverage for the preview contract (does not require LÖVE)."""
import re
from pathlib import Path


ROOT = Path(__file__).parents[1]


def _branch_ids(source):
    return set(re.findall(r"\bid\s*=\s*\"([a-z_]+)\"", source))


def test_every_tower_branch_has_an_authored_preview():
    tower_ids = _branch_ids((ROOT / "world/tower_defs.lua").read_text())
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    preview_ids = set(re.findall(r"^\t([a-z_]+)\s*=\s*\{duration=", preview, re.M))
    branch_ids = {
        "marksman", "rupture", "deep_freeze", "cold_field", "virulent", "contagion",
        "siege", "bombardment", "capacitor", "forked_lightning", "accelerator", "overcharged",
    }
    assert branch_ids <= tower_ids
    assert preview_ids == branch_ids


def test_preview_enemy_kinds_have_render_definitions():
    preview = (ROOT / "ui/specialization_preview.lua").read_text()
    enemy_defs = (ROOT / "world/enemy_defs.lua").read_text()
    defined_kinds = set(re.findall(r"^\t([a-z_]+)\s*=\s*{", enemy_defs, re.M))
    preview_groups = re.findall(r"enemies=enemies\((.*?)\), shots=", preview)
    preview_kinds = {
        kind
        for group in preview_groups
        for kind in re.findall(r'{"([a-z_]+)"', group)
    }
    assert preview_kinds <= defined_kinds


def test_picker_lifecycle_owns_preview_updates_and_release():
    picker = (ROOT / "ui/module_picker.lua").read_text()
    assert 'State.modulePicker.mode == "specialization"' in picker
    assert "SpecializationPreview.update(previews[i], dt)" in picker
    assert "SpecializationPreview.release(previews[i])" in picker
    assert picker.index("if not ModulePicker.isActive() then return end") < picker.index(
        "SpecializationPreview.update(previews[i], dt)"
    )


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
    assert re.search(r"setCanvas\(\{p\.canvas,\s*stencil\s*=\s*true}", preview)
    assert "lg.stencil(drawCanvasClip" in preview
