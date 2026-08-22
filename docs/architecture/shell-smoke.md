# Shell MVP — manual smoke checklist

1. `cd shell && export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test` — all green  
2. `swift run Jugnu` — menu bar shows **Jugnu**  
3. Option+Space (or menu **Open Palette**) opens the palette  
4. First-run: install recommended addons (or set `JUGNU_ADDON_PATH` to repo `addons/*`) and run mic-mute / focus-toggle / paste-plain  
5. Preferences: disable removes commands from palette; uninstall removes files + declared cleanup  

Registry URLs may stay empty until a GitHub Release; local/first-run install covers v0.
