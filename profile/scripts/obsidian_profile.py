"""Prepare a reversible CSS-snippet adapter; the profile manager owns writes.

Reads only Obsidian's vault registry and per-vault appearance settings. No note
content is inspected. Does not launch, stop, or modify the installed application.
"""
import json
from pathlib import Path

SNIPPET = "cupertino-window-controls"
SOURCE = Path(__file__).resolve().parents[1] / "assets/application-adapters/obsidian" / (SNIPPET + ".css")


def discover(home):
    home = Path(home)
    registry = home / ".config/obsidian/obsidian.json"
    if not registry.exists():
        return []
    data = json.loads(registry.read_text())
    result = []
    for item in data.get("vaults", {}).values():
        vault = Path(item.get("path", ""))
        if not vault.is_absolute() or not (vault / ".obsidian").is_dir():
            continue
        # The existing profile manager uses paths relative to HOME. Leave
        # external vaults unmodified instead of escaping that snapshot model.
        try:
            relative = vault.relative_to(home)
        except ValueError:
            continue
        if relative not in result:
            result.append(relative)
    return result


def managed_files(home):
    result = []
    for vault in discover(home):
        result.extend([str(vault / ".obsidian/appearance.json"),
                       str(vault / ".obsidian/snippets" / (SNIPPET + ".css"))])
    return result


def prepared_files(home):
    """Return {HOME-relative path: bytes}; caller must snapshot before writing."""
    home = Path(home)
    result = {}
    for vault in discover(home):
        appearance = vault / ".obsidian/appearance.json"
        target = home / appearance
        settings = json.loads(target.read_text()) if target.exists() else {}
        enabled = settings.get("enabledCssSnippets", [])
        if not isinstance(enabled, list) or not all(isinstance(x, str) for x in enabled):
            raise ValueError("Obsidian enabledCssSnippets must be a list of names")
        settings["enabledCssSnippets"] = list(dict.fromkeys(enabled + [SNIPPET]))
        result[str(appearance)] = (json.dumps(settings, ensure_ascii=False, indent=2)+"\n").encode()
        result[str(vault / ".obsidian/snippets" / (SNIPPET + ".css"))] = SOURCE.read_bytes()
    return result
