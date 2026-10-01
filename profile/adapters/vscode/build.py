#!/usr/bin/env python3
"""Build a separate, version-checked Code resource adapter; keep package untouched."""
import argparse, base64, hashlib, json, pathlib, re, shutil, subprocess
VERSION = '1.139.1'
ROOT = pathlib.Path(__file__).resolve().parent
PATCHED = ['out/main.js', 'out/vs/workbench/workbench.desktop.main.js',
           'out/vs/sessions/sessions.desktop.main.js']
PATTERN = re.compile(r'let (?P<v>\w+)=(?P<c>\w+)\.getValue\("window"\)\?\.controlsStyle;return (?P=v)==="custom"\|\|(?P=v)==="hidden"\?(?P=v):"native"')
def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
def build(source, target):
    app = source/'resources/app'
    if json.loads((app/'package.json').read_text())['version'] != VERSION:
        raise RuntimeError('Unsupported Code package version')
    if target.exists(): raise RuntimeError('Choose a new destination; never rewrite a live runtime')
    patched, originals = {}, {}
    for relative in PATCHED:
        file = app/relative
        originals[relative] = digest(file)
        text = file.read_text()
        if len(PATTERN.findall(text)) != 1: raise RuntimeError('Code control selector changed: '+relative)
        # Use Code's existing HTML controls and original native event handlers.
        # The titlebar style itself, fullscreen rules and security settings stay native.
        text = PATTERN.sub('return "custom"', text)
        if relative == 'out/main.js': text = 'import "./cupertino-frame.mjs";\n'+text
        patched[relative] = text
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['cp','-a','--reflink=auto',str(source),str(target)],check=True)
    for file in target.rglob('*'):
        if not file.is_symlink(): file.chmod(file.stat().st_mode | 0o200)
    target_app=target/'resources/app'
    for relative,text in patched.items(): (target_app/relative).write_text(text)
    shutil.copy2(ROOT/'frame.mjs', target_app/'out/cupertino-frame.mjs')
    # Integrity metadata describes this user-owned build, not the packaged one.
    product=json.loads((target_app/'product.json').read_text())
    for relative in PATCHED:
        key=relative.removeprefix('out/')
        if key in product.get('checksums',{}):
            product['checksums'][key]=base64.b64encode(hashlib.sha256((target_app/relative).read_bytes()).digest()).decode().rstrip('=')
    (target_app/'product.json').write_text(json.dumps(product,indent=2)+'\n')
    manifest={'version':VERSION,'originals':originals,'source':str(source),
              'runtimeSha256':digest(source/'code')}
    if digest(target/'code') != manifest['runtimeSha256']: raise RuntimeError('Runtime copy mismatch')
    (target/'cupertino-adapter.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Prepared Code '+VERSION+' with original runtime and native control handlers.')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=pathlib.Path,default=pathlib.Path('/usr/share/code'))
    parser.add_argument('--destination',type=pathlib.Path,required=True)
    args=parser.parse_args();build(args.source.resolve(),args.destination.resolve())
