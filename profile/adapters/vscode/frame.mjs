// User-owned resource adapter: native Code handlers and extension APIs stay intact.
import electron from 'electron';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const { app } = electron;
const root = path.join(os.homedir(), '.local/share/cupertino-glass/adapters/vscode');
const themeFile = path.join(os.homedir(), '.local/state/omarchy/current/theme.name');
const windows = new Map();
const read = file => { try { return fs.readFileSync(file, 'utf8'); } catch { return ''; } };
let current = '';
function appearance() {
  const theme = read(themeFile).trim();
  if (!['cupertino-dark', 'cupertino-light'].includes(theme)) return '';
  const base = read(path.join(root, 'appearance.css'));
  return base + (theme === 'cupertino-dark' ? `
    .monaco-workbench .part.titlebar,
    .monaco-workbench .part.titlebar.inactive { background-color:#24273a!important;color:#cad3f5!important; }
    .monaco-workbench .part.editor,.monaco-workbench .part.sidebar,
    .monaco-workbench .part.panel { background-color:#24273a!important; }
  ` : '');
}
function apply(entry) {
  entry.queue = entry.queue.then(async () => {
    const win = entry.win;
    if (win.isDestroyed() || win.webContents.isDestroyed()) return;
    const url = win.webContents.getURL();
    if (!/^(vscode-file:|file:)/.test(url) || !/\/vs\/(code|sessions)\/electron-browser\//.test(url)) return;
    if (entry.key) { await win.webContents.removeInsertedCSS(entry.key).catch(() => {}); entry.key = ''; }
    if (current) entry.key = await win.webContents.insertCSS(current, {cssOrigin: 'user'});
  }).catch(() => {});
}
app.on('browser-window-created', (_event, win) => {
  const entry = { win, key: '', queue: Promise.resolve() };
  windows.set(win.id, entry);
  win.webContents.on('did-finish-load', () => { entry.key = ''; current = appearance(); apply(entry); });
  win.once('closed', () => windows.delete(win.id));
});
const timer = setInterval(() => {
  const next = appearance();
  if (next === current) return;
  current = next;
  for (const entry of windows.values()) apply(entry);
}, 800);
timer.unref();
app.once('will-quit', () => clearInterval(timer));
