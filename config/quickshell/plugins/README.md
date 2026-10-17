# Quickshell plugins

Self-contained features live here — one folder per plugin, so everyone knows
where to find a component by name. To add one (e.g. `webapps` was second),
copy the `clipboard/` shape:

```
plugins/<name>/
  manifest.json   id "hyprqt.<name>", kinds, entryPoints.overlay
  <Name>.qml       the overlay UI (Scope + IPC + PanelWindow)
  <name>.py       backend for anything that touches I/O or exec (optional)
```

Conventions:

- **QML renders, Python acts.** Display logic (filtering, labels) stays in QML
  as pure functions over in-memory data. Anything that reads/writes files,
  spawns processes, or handles untrusted bytes (clipboard content, URLs,
  filenames) goes in the Python backend.
- **Never `sh -c` with interpolated data.** Quickshell `Process.command` and
  Python `subprocess` both take argv arrays — pass user-influenced values as
  separate arguments so hostile input (quotes, `$()`, backticks) is inert.
- **IPC per plugin.** Each overlay registers its own `IpcHandler` target
  (`clipboard`, `webapps`, …) with `toggle|show|hide` plus its own actions,
  and keybinds call `qs ipc call <target> <action>`.
- **Backend scripts are dependency-light.** Stdlib Python only; heavy tools
  (`wl-copy`, `wtype`, `xdg-open`, `notify-send`) are exec'd argv-style and
  treated as optional with graceful degradation.
- **State, not config.** Runtime data (history JSON, images) lives under
  `$XDG_STATE_HOME/theme/`, never in the repo. The repo holds code + static
  config only.
- **Register in `shell.qml`.** Directory import + qualified component:
  `import "plugins/<name>" as <Name>Plugin` then `<Name>Plugin.<Name> {}`.

Live symlinks: `install.sh`/`update.sh` link every new file under `.config`
automatically — after adding a plugin, run `./update.sh --skip-packages` (or
just link the new files) and restart quickshell.
