"""Small, dependency-free helpers for reading declarative Lua balance tables.

This is intentionally not a Lua parser.  It understands the subset used by the
balance sources, while ensuring braces in quoted strings and comments do not
change table boundaries.
"""
from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path


def _where(source_path: str | Path) -> str:
    return str(source_path)


def _brace_end(text: str, opening: int) -> int | None:
    """Return the matching close-brace index, ignoring strings and comments."""
    depth = 0
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False
    pos = opening
    while pos < len(text):
        char = text[pos]
        following = text[pos + 1] if pos + 1 < len(text) else ""
        if line_comment:
            line_comment = char != "\n"
        elif block_comment:
            if char == "]" and following == "]":
                block_comment = False
                pos += 1
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "-" and following == "-":
            if text[pos + 2:pos + 4] == "[[":
                block_comment = True
                pos += 3
            else:
                line_comment = True
                pos += 1
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return pos
        pos += 1
    return None


def table_body(text: str, declaration: str, source_path: str | Path) -> str:
    """Find *declaration* and return the contents of its balanced table."""
    if declaration == "return":
        pattern = r"\breturn\s*\{"
    else:
        pattern = (r"(?:^|\n)\s*(?:local\s+)?" + re.escape(declaration)
                   + r"\s*(?:=\s*)?\{")
    match = re.search(pattern, text)
    if not match:
        raise ValueError(
            f"missing Lua table declaration {declaration!r} in {_where(source_path)}"
        )
    opening = match.end() - 1
    end = _brace_end(text, opening)
    if end is None:
        raise ValueError(
            f"unterminated Lua table declaration {declaration!r} in {_where(source_path)}"
        )
    return text[opening + 1:end]


_ENTRY = re.compile(r"([a-z][a-z0-9_]*)\s*=\s*\{")


def iter_named_entries(body: str, declaration: str, source_path: str | Path) -> Iterator[tuple[str, str]]:
    """Yield top-level named table entries using one forward pass over *body*."""
    pos = 0
    while pos < len(body):
        match = _ENTRY.match(body, pos)
        if not match:
            # An anonymous top-level table cannot contain a named entry of the
            # requested declaration, so skip it as a unit as well.
            if body[pos] == "{":
                close = _brace_end(body, pos)
                pos = len(body) if close is None else close + 1
            else:
                pos += 1
            continue
        end, name = match.end(), match.group(1)
        opening = end - 1
        close = _brace_end(body, opening)
        if close is None:
            raise ValueError(
                f"unterminated Lua entry {name!r} in declaration {declaration!r} "
                f"in {_where(source_path)}"
            )
        yield name, body[opening + 1:close]
        pos = close + 1


def named_entries(body: str, declaration: str, source_path: str | Path) -> dict[str, str]:
    return dict(iter_named_entries(body, declaration, source_path))


def numeric_fields(body: str) -> dict[str, float]:
    return {key: float(value) for key, value in re.findall(
        r"\b(\w+)\s*=\s*([0-9]+(?:\.[0-9]+)?)", body)}


def numeric_field(body: str, key: str, source_path: str | Path,
                  entry_name: str, default: float | None = None) -> float:
    match = re.search(r"\b" + re.escape(key) + r"\s*=\s*([0-9]+(?:\.[0-9]+)?)", body)
    if match:
        return float(match.group(1))
    if default is not None:
        return default
    raise ValueError(f"missing numeric field {key!r} in entry {entry_name!r} in {_where(source_path)}")
