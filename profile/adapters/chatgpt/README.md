# Optional ChatGPT window adapter

Source adapter for the exact `chatgpt-bin 26.928.21956-1` package and Electron 42.3. It changes JavaScript resources in a separate local application copy, preserving the packaged installation. It is unofficial and version/hash guarded; a mismatched package falls back to the original executable.

The adapter adds window controls through Electron's native BrowserWindow actions. It is not automatically built by theme installation, and no application binaries are distributed here. Inspect `build.py` and `launch` before opting in. Close the application normally before rebuilding its local copy; preserve unsaved work. Double-click behavior on native draggable regions additionally depends on the optional, exact-version compositor bridge.

Refer to Electron's [custom title bar documentation](https://www.electronjs.org/docs/latest/tutorial/custom-title-bar) and [window API](https://www.electronjs.org/docs/latest/api/base-window). App updates require reviewing the adapter again.
