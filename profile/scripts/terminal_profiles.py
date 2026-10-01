"""Appearance-only profile overrides for the installed Foot and Alacritty terminals.

The caller owns snapshot/restore. Do not call this on the native Omarchy profile.
Existing commands, bindings, shell integration and scrollback settings are retained.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = {"foot": ".config/foot/foot.ini", "alacritty": ".config/alacritty/alacritty.toml"}


def configure_terminal(text, terminal, mode):
    if terminal not in FILES or mode not in ("light", "dark"):
        raise ValueError("Unsupported terminal profile")
    settings = json.loads((ROOT / "assets/terminal/settings.json").read_text())
    sections = settings[terminal]["common"] | settings[terminal][mode]
    for section, values in sections.items():
        text = _replace_section_values(text, section, values)
    return text


def _replace_section_values(text, section, values):
    """Replace scalar keys in one section without rewriting unrelated TOML/INI."""
    lines = text.splitlines(keepends=True)
    heading = re.compile(r"^\s*\[" + re.escape(section) + r"\]\s*(?:[#;].*)?$")
    start = next((i for i, line in enumerate(lines) if heading.match(line.strip())), None)
    if start is None:
        return text.rstrip() + "\n\n[" + section + "]\n" + "".join(f"{key} = {value}\n" for key, value in values.items())
    end = next((i for i in range(start + 1, len(lines)) if re.match(r"^\s*\[", lines[i])), len(lines))
    remaining = dict(values)
    for i in range(start + 1, end):
        match = re.match(r"^(\s*)([A-Za-z0-9_.-]+)\s*=", lines[i])
        if match and match.group(2) in values:
            key = match.group(2)
            lines[i] = f"{match.group(1)}{key} = {values[key]}\n"
            remaining.pop(key, None)
    lines[end:end] = [f"{key} = {value}\n" for key, value in remaining.items()]
    return "".join(lines)
