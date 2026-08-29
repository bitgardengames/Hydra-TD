"""Focused tests for the declarative Lua source helpers."""
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lua_source import named_entries, numeric_field, table_body


class LuaSourceTests(unittest.TestCase):
    SOURCE = "fixture.lua"

    def test_nested_tables_and_braces_in_strings(self):
        text = 'local defs = {\n alpha = { value = 2, nested = { text = "}" } },\n}'
        root = table_body(text, "defs", self.SOURCE)
        entries = named_entries(root, "defs", self.SOURCE)
        self.assertEqual(["alpha"], list(entries))
        self.assertEqual(2, numeric_field(entries["alpha"], "value", self.SOURCE, "alpha"))

    def test_adjacent_entries(self):
        root = "first = { value = 1 }, second = { value = 2 }"
        self.assertEqual(["first", "second"],
                         list(named_entries(root, "defs", self.SOURCE)))

    def test_missing_declaration_names_source(self):
        with self.assertRaisesRegex(ValueError, r"missing.*'missing'.*fixture\.lua"):
            table_body("local present = {}", "missing", self.SOURCE)

    def test_unterminated_declaration_names_source(self):
        with self.assertRaisesRegex(ValueError, r"unterminated.*'defs'.*fixture\.lua"):
            table_body("local defs = { nested = {}", "defs", self.SOURCE)

    def test_unterminated_entry_names_entry_and_source(self):
        root = "broken = { nested = {}"
        with self.assertRaisesRegex(ValueError, r"'broken'.*'defs'.*fixture\.lua"):
            named_entries(root, "defs", self.SOURCE)


if __name__ == "__main__":
    unittest.main()
