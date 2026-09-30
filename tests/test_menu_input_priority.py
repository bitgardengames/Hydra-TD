"""Source-level coverage for menu input priority (does not require LÖVE)."""

from pathlib import Path

ROOT = Path(__file__).parents[1]
MAIN = (ROOT / "main.lua").read_text()


def _function_body(name, next_name):
    start = MAIN.index(f"function love.{name}")
    end = MAIN.index(f"function love.{next_name}", start)
    return MAIN[start:end]


def _assert_menu_precedes_gameplay_modal(body, menu_call):
    mode_guard = body.index('if State.mode ~= "game" then')
    assert mode_guard < body.index(menu_call)
    assert body.index(menu_call) < body.index("ModulePicker.isActive()")


def test_menu_owns_mouse_press_before_gameplay_modals():
    body = _function_body("mousepressed", "wheelmoved")
    _assert_menu_precedes_gameplay_modal(body, "Menu.mousepressed(x, y, button)")


def test_menu_owns_mouse_release_before_gameplay_modals():
    body = _function_body("mousereleased", "keypressed")
    _assert_menu_precedes_gameplay_modal(body, "Menu.mousereleased(x, y, button)")


def test_menu_owns_keyboard_input_before_gameplay_modals():
    body = _function_body("keypressed", "gamepadpressed")
    _assert_menu_precedes_gameplay_modal(body, "Menu.keypressed(key)")
