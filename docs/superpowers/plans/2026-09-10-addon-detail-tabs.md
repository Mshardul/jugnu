# Addon Detail Tabs + Config (0065) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Checkboxes `- [ ]` for tracking.

**Goal:** Functional detail tabs (Overview/Commands/Settings), Run, prefs Installed + gear → Settings, full 0827 config pipeline, nudges as first consumer.

**Architecture:** Stack carries `AddonDetailTab`; JugnuUI detail + prefs Installed; Core config/state per 0827; App wires Run, TCC grant, open/reset.

**Tech Stack:** Swift / SwiftUI, Yams, XCTest, bash validate-addon.

**Spec:** [docs/architecture/2026-09-10-addon-detail-tabs-design.md](../../architecture/2026-09-10-addon-detail-tabs-design.md) + [0827](../../architecture/2026-08-27-addon-state-and-config-design.md)

## Global Constraints

- **Git:** do not run git / commit (`AGENTS.md`).
- Green `cd shell && swift test` after each phase.
- No gallery/genie/card visual redesign.
- Prefs = settings only (Installed is navigation).
- Config scalars only; unknown file keys block.

---

## Phase 1 — Detail tabs + navigation

**Files:** `ShellStack.swift` / tests; `AddonDetailView.swift`; `AddonCardView.swift`; `PrefsSelection` + `PrefsView`; `JugnuApp.swift`

- [x] Extend `detail(addonID:tab: AddonDetailTab)` default `.overview`; update all call sites / tests.
- [x] Rewrite `AddonDetailView` with tabs; `onRun: (String) -> Void`; Settings shows permissions (+ optional grant labels passed in).
- [x] Card gear (installed) → `onOpenSettings`; card tap → overview.
- [x] Prefs: `addonsInstalled` selection; Installed list UI; App supplies rows + push Settings.
- [x] App: `pushDetail(id, tab:)`; Run from detail via existing `runCommand` path when enabled.
- [x] `swift test` green.

## Phase 2 — 0827 Core

**Files:** `JugnuPaths`; installer/uninstall; `AddonManifest` config schema; `AddonConfigResolver`; `AddonRunner` / `RunRequest`; `validate-addon.sh`; `addon-manifest.md`; tests

- [x] Paths + state dir create on install / remove on uninstall.
- [x] Parse `config:` schema; reject bad schema at load/validate-addon.
- [x] Resolver: missing→defaults; syntax/invalid/unknown→error; merge.
- [x] Runner sets `JUGNU_STATE_DIR`, `JUGNU_CONFIG_DIR`; `config` on request always.
- [x] Unit tests for resolver + install state dir; `swift test` green.

## Phase 3 — Settings editors + recovery

- [x] Settings tab: PreferenceRows bound to config file via App callbacks (`loadConfigValues` / `saveConfigValues`).
- [x] On invoke config error: confirm/alert Open / Reset (generate template from schema).
- [x] `swift test` green.

## Phase 4 — Nudges + docs

- [x] `addons/jugnu.nudges/addon.yaml` config block; `bin/run` reads `config`.
- [x] Smoke section for 0065; CHANGELOG; tickets 0065 Done; stub 0067 visual; update 0827 status / architecture README.
- [x] Full `swift test` green.

---

## Spec coverage

| Requirement | Phase |
|---|---|
| Tabs + Run gate + deep link | 1 |
| Prefs Installed + gear | 1 |
| 0827 pipeline | 2 |
| Settings editors + recovery | 3 |
| Nudges consumer + docs | 4 |
| No visual redesign | all |
