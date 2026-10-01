"""Optional, reversible Code CLI selection. Packaged desktop entries use Exec=code."""
import os, shlex, json, re
from pathlib import Path
DESKTOPS = ('com.microsoft.VSCode.desktop', 'com.microsoft.VSCode.UrlHandler.desktop')
FILES = ('.local/bin/code', '.config/Code/User/settings.json',
         *('.local/share/applications/'+name for name in DESKTOPS))
def available(home):
    root=Path(home)/'.local/share/cupertino-glass'
    return os.access(root/'adapters/vscode/launch',os.X_OK) and os.access(root/'apps/vscode/1.139.1/bin/code',os.X_OK) and (root/'apps/vscode/1.139.1/cupertino-adapter.json').is_file()
def managed_files(home): return list(FILES) if available(home) else []
def parse_settings(text):
    # Preserve strings while accepting VS Code's comments and trailing commas.
    strings=r'"(?:\\.|[^"\\])*"'
    clean=re.sub(strings+r'|/\*[\s\S]*?\*/|//[^\r\n]*',
                 lambda m:m[0] if m[0].startswith('"') else ' ',text)
    clean=re.sub(strings+r'|,\s*(?=[}\]])',
                 lambda m:m[0] if m[0].startswith('"') else '',clean)
    value=json.loads(clean or '{}')
    if not isinstance(value,dict):raise ValueError('Code settings must be an object')
    return value
def prepared_files(home, mode='dark', settings_text=''):
    if not available(home): return {}
    launch=shlex.quote(str(Path(home)/'.local/share/cupertino-glass/adapters/vscode/launch'))
    result={FILES[0]:(f'#!/bin/sh\n# Cupertino profile selector; original package remains available.\nif [ -x {launch} ]; then exec {launch} "$@"; fi\nexec /usr/bin/code "$@"\n'.encode(),0o755)}
    # The shell's PATH may resolve /usr/bin/code before ~/.local/bin. Give both
    # desktop actions an absolute profile selector instead of depending on PATH.
    executable=str(Path(home)/'.local/share/cupertino-glass/adapters/vscode/launch')
    quoted='"'+executable.replace('\\','\\\\').replace('"','\\"').replace('`','\\`').replace('$','\\$')+'"'
    for name in DESKTOPS:
        local=Path(home)/'.local/share/applications'/name
        template=local if local.is_file() else Path('/usr/share/applications')/name
        if not template.is_file():continue
        desktop=template.read_text()
        desktop=re.sub(r'(?m)^Exec=(?:/usr/bin/)?code(?=\s|$)',lambda _: 'Exec='+quoted,desktop)
        result['.local/share/applications/'+name]=(desktop.encode(),local.stat().st_mode&0o777 if local.exists() else 0o644)
    if any((Path(home)/'.vscode/extensions').glob('catppuccin.catppuccin-vsc*/package.json')):
        settings=parse_settings(settings_text)
        settings['workbench.colorTheme']='Catppuccin Macchiato' if mode=='dark' else 'Catppuccin Latte'
        settings['workbench.preferredDarkColorTheme']='Catppuccin Macchiato'
        settings['workbench.preferredLightColorTheme']='Catppuccin Latte'
        result[FILES[1]]=((json.dumps(settings,ensure_ascii=False,indent=2)+'\n').encode(),0o644)
    return result
