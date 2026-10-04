"""Source-level contracts for the career, records, and codex screen."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREEN = (ROOT / "ui/menu/screens/career.lua").read_text()
MODEL = (ROOT / "ui/career_model.lua").read_text()
MENU = (ROOT / "ui/menu/menu.lua").read_text()
MAIN_MENU = (ROOT / "ui/menu/screens/main_menu.lua").read_text()
ENGLISH = (ROOT / "languages/enUS.lua").read_text()


def test_career_screen_is_reachable_and_registered():
    assert 'career = require("ui.menu.screens.career")' in MENU
    assert 'id = "career"' in MAIN_MENU
    assert 'set("career")' in MAIN_MENU


def test_screen_exposes_all_three_views_and_navigation():
    assert 'local TABS = {"career", "records", "codex"}' in SCREEN
    assert 'if key == "escape" then goBack()' in SCREEN
    assert 'elseif key == "left" then switchTab(selectedTab - 1)' in SCREEN
    assert 'elseif key == "right" then switchTab(selectedTab + 1)' in SCREEN
    assert "function Screen.wheelmoved" in SCREEN


def test_model_reads_existing_persistent_telemetry():
    for field in (
        "ENEMIES_KILLED",
        "BOSSES_KILLED",
        "towerHistory",
        "TOWER_UPGRADES",
        "unlockedAchievements",
        "mapStats",
        "encounteredEnemies",
        "enemyHistory",
    ):
        assert field in MODEL
    assert 'record.bestScore' in MODEL
    assert 'record.fastestClear' in MODEL
    assert 'record.fewestLeaks' in MODEL


def test_codex_preserves_discovery_and_unknown_enemy_states():
    assert 'encountered[kind] == true' in MODEL
    assert 'L("career.unknownEnemy")' in SCREEN
    assert 'EnemyRenderer.drawEnemyPortrait' in SCREEN
    assert 'L(enemy.def.descriptionKey)' in SCREEN


def test_english_catalog_has_career_labels():
    assert 'career = "Career & Records"' in ENGLISH
    for label in (
        'title = "COMMAND CENTER"',
        'records = "Records"',
        'codex = "Enemy Codex"',
        'recordScore = "Best Score"',
        'unknownEnemy = "Unknown Enemy"',
    ):
        assert label in ENGLISH
