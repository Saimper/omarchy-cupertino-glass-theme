"""Change browser appearance only while its profile is closed.

Snapshots contain appearance leaves only, never browsing data. Running browsers
are left alone. Launchers and a short-lived restore worker finish pending edits
after the browser releases its profile lock.
"""
import json, os, pathlib, tempfile

BROWSERS = {
    'chromium': ('.config/chromium', '/usr/bin/chromium'),
    'brave': ('.config/BraveSoftware/Brave-Browser', '/usr/bin/brave'),
}
VALUES = {'extensions.theme.id': '', 'extensions.theme.system_theme': 1,
          'browser.custom_chrome_frame': True}

def get(data, key):
    for part in key.split('.'):
        if not isinstance(data, dict) or part not in data: return {'present': False}
        data = data[part]
    return {'present': True, 'value': data}

def put(data, key, record):
    parts = key.split('.')
    node = data
    for part in parts[:-1]:
        if not record['present'] and part not in node: return
        node = node.setdefault(part, {})
    if record['present']: node[parts[-1]] = record['value']
    else: node.pop(parts[-1], None)

def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.cupertino-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, ensure_ascii=False); stream.write('\n')
            stream.flush(); os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def busy(folder):
    lock = folder/'SingletonLock'
    if not lock.is_symlink(): return False
    try:
        pid = int(os.readlink(lock).rsplit('-', 1)[1])
        os.kill(pid, 0)
        return True
    except ProcessLookupError: return False
    except (ValueError, PermissionError): return True

def sync(home, browser, active=None):
    home = pathlib.Path(home)
    folder = home/BROWSERS[browser][0]
    if not folder.exists(): return 'absent'
    if busy(folder): return 'pending'
    if active is None:
        theme = home/'.local/state/omarchy/current/theme.name'
        active = theme.exists() and theme.read_text().strip() in ('cupertino-light', 'cupertino-dark')
    state = home/'.local/state/cupertino-glass/browser-appearance'/f'{browser}.json'
    saved = json.loads(state.read_text()) if state.exists() else {}
    for prefs in folder.glob('*/Preferences'):
        if prefs.is_symlink() or not prefs.is_file(): continue
        data = json.loads(prefs.read_text())
        profile = prefs.parent.name
        if active:
            if profile not in saved:
                saved[profile] = {key: get(data, key) for key in VALUES}
                atomic(state, saved)
            for key, value in VALUES.items(): put(data, key, {'present': True, 'value': value})
        elif profile in saved:
            for key, original in saved[profile].items():
                # Preserve any explicit later appearance changes by the user.
                if get(data, key) == {'present': True, 'value': VALUES[key]}:
                    put(data, key, original)
            del saved[profile]
        else: continue
        atomic(prefs, data)
    if state.exists(): atomic(state, saved)
    return 'applied' if active else 'restored'

if __name__ == '__main__':
    import sys, time
    home = pathlib.Path.home()
    if len(sys.argv) == 2 and sys.argv[1] == 'settle':
        # Only spawned on an explicit profile change; exits after both close or
        # the next profile activation cancels it. No process is killed.
        while True:
            theme = home/'.local/state/omarchy/current/theme.name'
            if theme.read_text().strip() in ('cupertino-light', 'cupertino-dark'): break
            results = [sync(home, b, False) for b in BROWSERS]
            if 'pending' not in results: break
            time.sleep(2)
    else:
        print(json.dumps({b: sync(home, b) for b in BROWSERS}))
