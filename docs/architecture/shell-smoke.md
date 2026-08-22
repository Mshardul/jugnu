# Shell MVP — smoke checklist

## Automated (verified 2026-08-22; Core suite re-verified 2026-08-23)

- [x] `cd shell && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test --filter JugnuCoreTests` — green
- [x] CI uses `--filter JugnuCoreTests` so `JugnuCoreLiveTests` never runs on GitHub
- [x] `xcodegen generate` → `Jugnu.xcodeproj`; `xcodebuild -scheme Jugnu` — **BUILD SUCCEEDED** (re-run after this epic’s asset/catalog changes)
- [x] Launch `Jugnu.app` — process starts (menu bar agent)
- [x] Addon CLI — mic-mute, focus-toggle, paste-plain return `ok: true`
- [x] Release `addons-v1.0.0` + `registry/addons.json` on `main`

Live registry/install (not CI; uses the network and can touch launchd):

```bash
make verify-live
# or: cd shell && swift test --filter JugnuCoreLiveTests
```

## Manual (on your Mac)

Walk this after the 2026-08-23 palette + addon UI product pass. Leave items unchecked until you actually do them.

### Palette

- [ ] Option+Space (or menu **Open Palette**) opens the palette
- [ ] Typing reaches the search field (not the frontmost app)
- [ ] Escape closes; arrows move the highlight; Enter runs the highlighted row
- [ ] Fuzzy query `mcmt` ranks **Mic Mute** above unrelated keyword matches
- [ ] Empty catalog copy reads `No addons yet — install some to get started.`
- [ ] Did-you-mean row (nonsense query with installed addons) shows subtitle `Did you mean this?`
- [ ] Star pins/unpins without running the command
- [ ] On a multi-monitor Mac, the palette opens on the screen that contains the cursor

### Theme, motion, sound

- [ ] Preferences → Theme: Firefly / Terminal Phosphor / Rose Quartz each restyle an already-open palette without restart
- [ ] A ColorPicker change on one token (light or dark) pushes live to the open palette
- [ ] Invalid hex in `~/.config/jugnu/jugnu.yaml` falls back per-field instead of crashing
- [ ] Terminal Phosphor uses monospaced UI type; the other two stay SF Pro
- [ ] Reduce Motion on: no glow-bloom; palette fade is instant (or near-instant); toasts do not fade
- [ ] Command success plays Tink, failure plays Basso; Preferences sound toggle silences both

### Keyboard-only panels

- [ ] Confirm (ui-demo): Tab Cancel → Confirm; Return confirms; Escape cancels
- [ ] List (`clipboard-history`): filter as you type; arrows; Return selects; Escape cancels
- [ ] Form (ui-demo): Tab through fields; Return submits; Escape cancels
- [ ] Follow-up failure shows an inline banner and keeps the panel open (no toast-and-dismiss)

### First-run, addons, chrome

- [ ] First-run installs the starter set from registry (falls back to local `addons/` if offline): `mic-mute`, `focus-toggle`, `paste-plain`, `floating-note`, `ports`
- [ ] Preferences → **Install starter addons** downloads zips + verifies sha256
- [ ] Preferences: disable removes from palette; uninstall removes files + declared cleanup
- [ ] **Floating Note**: type, Cmd+S, close, reopen — text persisted by the addon
- [ ] Menu bar uses the template firefly icon (tints with the menu bar); click opens the menu

### Permissions / hotkey (manual only — do not automate against TCC)

- [ ] Deny a permission an addon needs: the shell shows a human sentence, not `ManifestLoaderError…`
- [ ] Hotkey conflict (e.g. Option+Space already bound): registration fails visibly; changing `shell.hotkey` in config or first-run ⌘Space opt-in recovers

### Felt speed (DEBUG `InvokeTrace`)

Budgets from [addon-ui-speed-design.md §6](./2026-08-22-addon-ui-speed-design.md). Fix only if a real miss shows up — no new logging infra in this epic.

| Path | Target | Hard ceiling |
|---|---|---|
| Hotkey → palette first paint | ≤ 50 ms | 100 ms |
| Command → toast visible | ≤ 150 ms | 400 ms |
| Command → panel chrome (skeleton OK) | ≤ 100 ms | 200 ms |
| Panel chrome → useful content | ≤ 300 ms | 800 ms |
| Follow-up action → feedback | ≤ 150 ms | 400 ms |

- [ ] DEBUG console `InvokeTrace` lines stay inside those budgets on toast addons (mic-mute) and a list panel (clipboard-history)

Default catalog URL: `https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/addons.json` (`shell.registry_url` in config).
