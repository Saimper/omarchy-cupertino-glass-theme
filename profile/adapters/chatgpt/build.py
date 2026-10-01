#!/usr/bin/env python3
"""Build a version-checked, separate ChatGPT application. Never edits /usr/lib."""
import argparse, copy, hashlib, json, pathlib, shutil, struct, subprocess

VERSION = '26.928.21956'
MAIN = '.vite/build/main-BbeJ4AAR.js'
MAIN_SHA = '1ff5a43bde26ea6c1b77dbcf782625c890e35a836d489163c19d5ba9942d68b4'
ROOT = pathlib.Path(__file__).resolve().parent

def index(archive):
    with archive.open('rb') as stream:
        _, size, _, length = struct.unpack('<4I', stream.read(16))
        return json.loads(stream.read(length)), 8 + size

def entries(node, prefix=''):
    for name, entry in node['files'].items():
        name = prefix + name
        if 'files' in entry: yield from entries(entry, name + '/')
        else: yield name, entry

def replace_once(text, old, new):
    if text.count(old) != 1: raise RuntimeError('Patch anchor changed: ' + old[:100])
    return text.replace(old, new, 1)

def build(source, destination, refresh=False):
    existing=destination.exists()
    if existing:
        if not refresh: raise RuntimeError('Destination exists; choose a fresh directory or --refresh.')
        manifest=json.loads((destination/'cupertino-adapter.json').read_text())
        if manifest.get('version') != VERSION or manifest.get('originalMainSha256') != MAIN_SHA:
            raise RuntimeError('The destination is not this adapter version.')
    if destination == source or source in destination.parents:
        raise RuntimeError('The application package must remain read-only.')
    archive = source / 'resources/app.asar'
    archive_stat = archive.stat()
    def digest(file):
        with file.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
    executable_hash=digest(source/'ChatGPT')
    executable_stat=(source/'ChatGPT').stat()
    if existing and digest(destination/'ChatGPT') != executable_hash:
        raise RuntimeError('Runtime changed; build a fresh application directory.')
    header, base = index(archive)
    original = dict(entries(header))
    def read(name):
        entry = original[name]
        with archive.open('rb') as stream:
            stream.seek(base + int(entry['offset']))
            return stream.read(entry['size'])
    package = json.loads(read('package.json'))
    if package['version'] != VERSION: raise RuntimeError('Unsupported ChatGPT version.')
    main = read(MAIN)
    if hashlib.sha256(main).hexdigest() != MAIN_SHA:
        raise RuntimeError('ChatGPT resource checksum changed; refusing a blind patch.')
    main = 'const __cupertinoFrame=require("./cupertino-frame.cjs");\n' + main.decode()
    main = replace_once(main, 'getPrimaryMinimumSize(){return{width:480,height:600}}',
        'getPrimaryMinimumSize(){return{width:480,height:__cupertinoFrame.minimumHeight(600)}}')
    main = replace_once(main, 'R=new g.BrowserWindow(L);if(r)',
        'R=new g.BrowserWindow(__cupertinoFrame.options(L,u));__cupertinoFrame.attach(R,u,()=>this.syncPrimaryMinimumSize());if(r)')
    main = replace_once(main, 'n.setTitleBarOverlay(j9(t))', '__cupertinoFrame.setOverlay(n,j9(t))')
    main = replace_once(main, 'e.setTitleBarOverlay(j9(this.windowZooms.get(e.id)))',
        '__cupertinoFrame.setOverlay(e,j9(this.windowZooms.get(e.id)))')
    replacements = {
        MAIN: main.encode(),
        '.vite/build/preload.js': read('.vite/build/preload.js') + b'\n' + (ROOT/'preload.js').read_bytes(),
        '.vite/build/cupertino-frame.cjs': (ROOT/'frame.cjs').read_bytes(),
    }
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Independent file extents: no hard links to mutable package resources.
    if not existing:
        subprocess.run(['cp','-a','--reflink=auto',str(source),str(destination)],check=True)
    for file in destination.rglob('*'):
        if not file.is_symlink(): file.chmod(file.stat().st_mode | 0o200)
    updated = copy.deepcopy(header)
    for name in replacements:
        node = updated
        parts=name.split('/')
        for part in parts[:-1]: node=node['files'].setdefault(part,{'files':{}})
        node['files'].setdefault(parts[-1],{})
    offset=0
    for name, entry in entries(updated):
        if entry.get('unpacked') or 'link' in entry: continue
        if name in replacements:
            data=replacements[name]; block=4*1024*1024
            entry.update(size=len(data),integrity={'algorithm':'SHA256',
                'hash':hashlib.sha256(data).hexdigest(),'blockSize':block,
                'blocks':[hashlib.sha256(data[i:i+block]).hexdigest() for i in range(0,len(data),block)]})
        entry['offset']=str(offset); offset+=entry['size']
    encoded=json.dumps(updated,separators=(',',':'),ensure_ascii=False).encode()
    payload=4+len(encoded); padding=(-payload)%4; pickle_size=4+payload+padding
    target=destination/'resources/app.asar'
    temporary=target.with_suffix('.asar.new')
    with temporary.open('wb') as out, archive.open('rb') as stream:
        out.write(struct.pack('<4I',4,pickle_size,payload+padding,len(encoded)))
        out.write(encoded);out.write(b'\0'*padding)
        for name, entry in entries(updated):
            if entry.get('unpacked') or 'link' in entry: continue
            if name in replacements:out.write(replacements[name]);continue
            old=original[name];stream.seek(base+int(old['offset']));remaining=old['size']
            while remaining:
                data=stream.read(min(remaining,4*1024*1024))
                if not data:raise RuntimeError('Truncated source archive')
                out.write(data);remaining-=len(data)
    temporary.replace(target)
    manifest={'version':VERSION,'source':str(source),'originalMainSha256':MAIN_SHA,
        'adapterFiles':list(replacements),'sourceExecutableSha256':executable_hash,
        'adapterExecutableSha256':digest(destination/'ChatGPT'),
        'sourceArchiveStat':{'size':archive_stat.st_size,'mtimeNs':archive_stat.st_mtime_ns},
        'sourceExecutableStat':{'size':executable_stat.st_size,'mtimeNs':executable_stat.st_mtime_ns}}
    (destination/'cupertino-adapter.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=pathlib.Path,default=pathlib.Path('/usr/lib/chatgpt'))
    parser.add_argument('--destination',type=pathlib.Path,required=True)
    parser.add_argument('--refresh',action='store_true',help='Refresh only an existing, identified local adapter.')
    args=parser.parse_args();build(args.source.resolve(),args.destination.resolve(),args.refresh)
