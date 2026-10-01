"""Prepare user launchers for the optional, versioned ChatGPT adapter.

The profile manager owns snapshots and writes. This module never starts an
application, edits package files, or reads the user's ChatGPT application data.
"""
import os
from pathlib import Path
import re
import shlex

VERSION = "26.928.21956-stable-controls"
CLI = ".local/bin/chatgpt"
DESKTOP = ".local/share/applications/chatgpt.desktop"
FILES = (CLI, DESKTOP)


def selector(home):
    return Path(home) / ".local/share/cupertino-glass/adapters/chatgpt/launch"


def available(home):
    application = Path(home) / ".local/share/cupertino-glass/apps/chatgpt" / VERSION
    launch = selector(home)
    return (launch.is_file() and os.access(launch, os.X_OK)
            and (application / "ChatGPT").is_file()
            and os.access(application / "ChatGPT", os.X_OK)
            and (application / "cupertino-adapter.json").is_file())


def managed_files(home):
    return list(FILES) if available(home) else []


def desktop_exec_path(path):
    """Quote an executable using Desktop Entry Exec rules, not shell syntax."""
    # Desktop Entry unescapes values before Exec tokenization. Backslashes in
    # quoted Exec arguments therefore need two escaping layers.
    text = str(path)
    if any(char in text for char in ("%", "=", "\n", "\r")):
        # The executable token cannot contain '='; field codes inside quoted
        # executable names are undefined. Fail before any launcher is replaced.
        raise ValueError("ChatGPT selector path cannot be represented safely in Desktop Exec")
    text = text.replace("\\", "\\\\\\\\").replace('"', '\\\\"')
    text = text.replace("$", "\\\\$").replace("`", "\\\\`")
    return ('"' + text + '"').encode()


def rewrite_desktop(data, launch):
    """Replace only a direct /usr/bin/chatgpt command; preserve every other byte."""
    command = desktop_exec_path(launch)
    pattern = rb'(?m)^([ \t]*Exec[ \t]*=[ \t]*)(?:"/usr/bin/chatgpt"|/usr/bin/chatgpt)(?=[ \t\r\n]|$)'
    return re.sub(pattern, lambda match: match[1] + command, data)


def prepared_files(home, desktop_data=None, desktop_mode=0o644):
    """Return {HOME-relative path: (bytes, mode)} after the caller snapshots it.

    An absent local desktop stays absent: the packaged Exec=chatgpt command can
    use the user CLI. We do not synthesize or copy unknown desktop metadata.
    """
    if not available(home):
        return {}
    launch = selector(home)
    quoted = shlex.quote(str(launch))
    wrapper = ("#!/bin/sh\n# Cupertino Glass: profile-selected ChatGPT launcher.\n"
               f"if [ -x {quoted} ]; then\n  exec {quoted} \"$@\"\nfi\n"
               "exec /usr/bin/chatgpt \"$@\"\n").encode()
    result = {CLI: (wrapper, 0o755)}
    if desktop_data is not None:
        updated = rewrite_desktop(desktop_data, launch)
        if updated != desktop_data:
            result[DESKTOP] = (updated, desktop_mode)
    return result
