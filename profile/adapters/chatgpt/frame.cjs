'use strict';
// Local resource adapter. This module never modifies the packaged executable.
const { app, BrowserWindow, ipcMain } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const channel = 'cupertino:local-window-frame:v1';
const windows = new Map();
const themePath = path.join(os.homedir(), '.local/state/omarchy/current/theme.name');
const stylePath = path.join(os.homedir(), '.local/share/cupertino-glass/adapters/chatgpt/appearance.css');
const appearances = new Set(['primary', 'detached', 'quickChat']);
function readTheme() {
  try { return fs.readFileSync(themePath, 'utf8').trim(); } catch { return ''; }
}
let theme = readTheme();
function readStyle() { try { return fs.readFileSync(stylePath, 'utf8'); } catch { return ''; } }
let css = readStyle();
function active() { return theme === 'cupertino-dark' || theme === 'cupertino-light'; }
function state(win) {
  return { adapted: windows.has(win.id), active: active(), theme, css,
    focused: win.isFocused(), maximized: win.isMaximized(), fullscreen: win.isFullScreen() };
}
function publish(win) {
  if (!win.isDestroyed() && !win.webContents.isDestroyed())
    win.webContents.send(channel, state(win));
}
function trusted(event, win) {
  if (!win || !windows.has(win.id) || event.sender !== win.webContents ||
      event.senderFrame !== event.sender.mainFrame) return false;
  try {
    const url = new URL(event.senderFrame.url);
    return (url.protocol === 'app:' && (url.host === '-' || url.host === '')) ||
      (url.protocol === 'file:' && decodeURIComponent(url.pathname) ===
        path.join(app.getAppPath(), 'webview/index.html'));
  } catch { return false; }
}
ipcMain.handle(channel, (event, action) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!trusted(event, win)) return null;
  switch (action) {
    case 'state': break;
    case 'close': win.close(); return null; // Keeps the application's close confirmation.
    case 'minimize': win.minimize(); break;
    case 'maximize': win.isMaximized() ? win.unmaximize() : win.maximize(); break;
    default: return null;
  }
  return win.isDestroyed() ? null : state(win);
});
const poll = setInterval(() => {
  const next = readTheme();
  const nextCss = readStyle();
  if (next === theme && nextCss === css) return;
  theme = next;
  css = nextCss;
  for (const [id, entry] of windows) {
    if (entry.win.isDestroyed()) { windows.delete(id); continue; }
    entry.syncMinimum();
    publish(entry.win);
  }
}, 800);
poll.unref();
app.once('will-quit', () => { clearInterval(poll); ipcMain.removeHandler(channel); });
exports.minimumHeight = original => active() ? Math.min(original, 360) : original;
exports.options = (options, appearance) => {
  if (process.platform !== 'linux' || !active() || !appearances.has(appearance)) return options;
  // Suppress the runtime's right-side overlay before creating the window.
  return { ...options, titleBarStyle: 'hidden', titleBarOverlay: false };
};
exports.attach = (win, appearance, syncMinimum) => {
  if (process.platform !== 'linux' || !active() || !appearances.has(appearance)) return;
  windows.set(win.id, { win, syncMinimum });
  for (const event of ['focus', 'blur', 'maximize', 'unmaximize', 'enter-full-screen', 'leave-full-screen'])
    win.on(event, () => publish(win));
  win.once('closed', () => windows.delete(win.id));
  win.webContents.on('did-finish-load', () => publish(win));
};
exports.setOverlay = (win, overlay) => {
  if (!windows.has(win.id)) win.setTitleBarOverlay(overlay);
};
