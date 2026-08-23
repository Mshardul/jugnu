# Plan: view types (0045)

**Spec:** [2026-08-24-view-types.md](../../architecture/2026-08-24-view-types.md)  
**Status:** Spec approved — **do not implement until the user asks**

## Goal

Shell size table keyed by the ten view-type ids; manifest `view_types` / command `view` / `ui.view`; click-outside split; multi-screen `visibleFrame` clamps.

## Slices (when implementing)

1. `ViewType` enum + size function + unit tests (min/max, portrait monitor, ultrawide cap, `NSScreen.main` not used when panel has a screen).
2. Map 0008 presets to default types (`seek`/`palette`/`grid`/`rail`/`ask`/`rows`/`fields`).
3. Click-outside: ignore for `board`/`spread`/`canvas`.
4. Manifest + `validate-addon.sh` allow-list.
5. Run JSON `ui.view` override + error on unknown id.
6. Manual smoke on built-in + external display if present.

TDD at the size-function and stack/dismiss boundary. No new `NSWindow`.
