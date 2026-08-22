# Shell MVP — smoke checklist

## Automated (verified 2026-08-22)

- [x] `cd shell && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test` — 19/19 green  
- [x] `xcodegen generate` → `Jugnu.xcodeproj`; `xcodebuild -scheme Jugnu` — **BUILD SUCCEEDED**  
- [x] Launch `Jugnu.app` — process starts (menu bar agent)  
- [x] Addon CLI (`echo '{"api":1,"op":"run",...}' | ./bin/run`) — mic-mute, focus-toggle, paste-plain return `ok: true`  

## Manual (on your Mac)

- [ ] Option+Space (or menu **Open Palette**) opens the palette  
- [ ] First-run installs recommended addons (or `JUGNU_ADDON_PATH`) and palette runs the three commands  
- [ ] Preferences: disable removes from palette; uninstall removes files + declared cleanup  

Registry URLs may stay empty until a GitHub Release; local/first-run install covers v0.
