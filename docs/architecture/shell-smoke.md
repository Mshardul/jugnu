# Shell MVP — smoke checklist

## Automated (verified 2026-08-22)

- [x] `cd shell && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test` — green  
- [x] `xcodegen generate` → `Jugnu.xcodeproj`; `xcodebuild -scheme Jugnu` — **BUILD SUCCEEDED**  
- [x] Launch `Jugnu.app` — process starts (menu bar agent)  
- [x] Addon CLI — mic-mute, focus-toggle, paste-plain return `ok: true`  
- [x] Release `addons-v1.0.0` + `registry/addons.json` on `main`  

## Manual (on your Mac)

- [ ] Option+Space (or menu **Open Palette**) opens the palette  
- [ ] First-run installs recommended addons **from registry** (falls back to local `addons/` if offline)  
- [ ] Preferences → **Install recommended from registry** downloads zips + verifies sha256  
- [ ] Preferences: disable removes from palette; uninstall removes files + declared cleanup  

Default catalog URL: `https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/addons.json` (`shell.registry_url` in config).
