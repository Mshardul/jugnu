# Keep Current Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship keep-current: the shell zip uses the same trust pipeline as addons, launch/manual checks confirm before write, and first launch is two steps then in-panel Browse.

**Architecture:** Core owns registry row, SemVer/skip, download/hash/extract, app-package gates, apply-script bytes, and addon-bulk diff. App owns yaml prefs, menu, launch `Task` after first paint, in-panel confirms via existing `ShellHost.pushFollowUp`, quit+spawn, and the first-run window. Do not run the shell zip through `AddonInstaller`. Do not add Sparkle.

**Tech Stack:** Swift / JugnuCore + App, existing `AllowlistedDownloadSession` + `ZipExtractor` + `PackageGates.compareSemVer` / `checkEntrypoint`, `UIDescriptor` `.confirm`, XCTest fixtures.

**Spec:** [docs/architecture/2026-09-07-keep-current-design.md](../../architecture/2026-09-07-keep-current-design.md)

## Global Constraints

- **Git:** do not run git, do not branch, do not commit (`AGENTS.md`). Skip every “Commit” instinct; mark steps done after tests pass.
- **Every phase ships green.** End each phase with `cd shell && swift test` green before starting the next.
- **Honor the locked tables.** Defaults both on; app always prompt-and-restart; addons bulk confirm; launch check after first paint; thin POSIX helper; no Sparkle; no 0825 prefs rail.
- **Layering:** download / extract / gates / skip / diff stay in **JugnuCore**. Confirms, menu, first-run, `NSWorkspace`/`Process` spawn of the helper live in **App**. No AppKit in Core.
- **Errors:** every new error that can reach the user gets a `UserFacingError.message(for:)` arm before the phase is Done. Launch-check failures stay silent (phase 3).
- **Not this plan:** Sparkle, notarization, relocating into `/Applications`, menu-bar badge, daily timer, privileged helper, progress window.

---

## File map

| Path | Phase | Responsibility |
|---|---|---|
| `registry/jugnu-app.json` | 1 | App registry row (`version` = current `0.1.0` so checks no-op until a newer tag) |
| `shell/Sources/JugnuCore/AppRegistry.swift` | 1 | `AppRegistryEntry` + `RegistryClient.fetchAppRegistry` + URL derivation |
| `shell/Sources/JugnuCore/Install/AppUpdate.swift` | 1 | SemVer availability + minMacOS |
| `shell/Sources/JugnuCore/Install/AppUpdateSkip.swift` | 1 | Launch skip rules (pure, injectable) |
| `shell/Sources/JugnuCore/Models.swift` | 1, 3 | `helpersCatalogURL`-style `appRegistryURL(from:)`; yaml `keep_app_current` / `keep_addons_current` |
| `shell/Sources/JugnuCore/Paths.swift` | 2 | `appUpdateDir`, `appUpdateStagingDir` |
| `shell/Sources/JugnuCore/Install/AppPackage.swift` | 2 | Find `Jugnu.app`, identity + version + universal gates |
| `shell/Sources/JugnuCore/Install/AppInstaller.swift` | 2 | Download → sha256 → extract → gates; staging orphan recover |
| `shell/Sources/JugnuCore/Install/AppApplyHelper.swift` | 2 | POSIX script bytes + sidecar plan (pid/source/dest) |
| `shell/Sources/JugnuCore/AppUpdateConfirmation.swift` | 3 | `confirmAppUpdateUI(version:notes:)` |
| `shell/Sources/JugnuCore/Install/AddonBulkUpdate.swift` | 4 | Diff installed vs registry |
| `shell/Sources/JugnuCore/AddonBulkConfirmation.swift` | 4 | `confirmAddonBulkUI(count:)` |
| `shell/Sources/JugnuCore/UserFacingError.swift` | 1–5 | New copy |
| `shell/App/KeepCurrentCoordinator.swift` | 3–4 | Launch/manual check, confirm order, apply/quit |
| `shell/App/MenuBarController.swift` | 3 | **Check for Updates…** (normal menu only) |
| `shell/App/PrefsView.swift` | 3 | Updates section |
| `shell/App/JugnuApp.swift` | 3–5 | After-paint `Task`; first-run `pushCatalog` |
| `shell/App/FirstRunWindow.swift` | 5 | Two steps |
| `shell/App/AppModel.swift` | 3, 5 | Save keep flags; first-run selected ids |
| `docs/architecture/shell-smoke.md` | 5 | Keep-current manual section |
| `PRIVACY.md`, `registry/README.md`, `docs/release-process.md`, `CHANGELOG.md` | 5 | Shipping docs |

---

## Phase 1 — App registry + compare + skip (no UI)

**Ships:** `jugnu-app.json`, fetch, SemVer/minMacOS, skip helper. No download of the zip.

### 1.1 Registry file + decode

**Files:**
- Create: `registry/jugnu-app.json`
- Create: `shell/Sources/JugnuCore/AppRegistry.swift`
- Test: `shell/Tests/JugnuCoreTests/AppRegistryTests.swift`

- [ ] **Step 1:** Write failing tests for decode (required fields), empty `sha256`, wrong `id`, `RegistryClient.fetchAppRegistry` mapping HTTP/invalid JSON to `RegistryClientError` (reuse those cases).

```swift
public struct AppRegistryEntry: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var version: String
    public var minMacOS: String
    public var url: String
    public var sha256: String
    public var notes: String?

    public init(
        id: String, name: String, version: String, minMacOS: String,
        url: String, sha256: String, notes: String? = nil
    ) { ... }
}
```

Decode: `sha256` empty or missing → throw `AppUpdateError.sha256Required` (do not decode as `""` and skip later). `id` must be `jugnu.shell` after decode or throw `AppUpdateError.invalidId`.

```swift
public enum AppUpdateError: Error, Equatable {
    case sha256Required
    case invalidId(String)
    case invalidRegistryURL
    case versionMismatch(expected: String, actual: String)
    case bundleIdentity
    case destNotWritable
    case helperSpawnFailed
    case macOSTooOld(required: String)
}
```

- [ ] **Step 2:** Implement `RegistryClient.fetchAppRegistry(from: URL) async throws -> AppRegistryEntry` — same HTTP session style as `fetchHelpers` (`URLSession.shared` for JSON is OK; zip download in phase 2 uses `AllowlistedDownloadSession`).

- [ ] **Step 3:** Add `ShellConfig.appRegistryURL(from registryURL: String) -> String?` next to `helpersCatalogURL`. If `registryURL` has suffix `addons.json`, replace with `jugnu-app.json`. Else return `nil` (fail closed).

```swift
XCTAssertEqual(
    ShellConfig.appRegistryURL(from: ShellConfig.defaultRegistryURL),
    "https://raw.githubusercontent.com/Mshardul/jugnu/main/registry/jugnu-app.json"
)
XCTAssertNil(ShellConfig.appRegistryURL(from: "https://example.com/catalog"))
```

- [ ] **Step 4:** Write `registry/jugnu-app.json` with `version` **`0.1.0`** (matches `Info.plist` / `MARKETING_VERSION`), `minMacOS` `14.0`, GitHub-shaped `url` for a future `shell-v0.1.0` asset, **non-empty** sha256 (64 hex zeros is fine — zip is never fetched while versions match).

- [ ] **Step 5:** Map `AppUpdateError.sha256Required` / `invalidId` / `invalidRegistryURL` in `UserFacingError`.

### 1.2 Availability

**Files:** Create `shell/Sources/JugnuCore/Install/AppUpdate.swift`; Test: `AppUpdateTests.swift`

- [ ] **Step 1:** Failing tests: newer → `.available`; same/older → `.upToDate`; invalid SemVer → not available / throw; `minMacOS` greater than injected OS → `.blockedMacOS`.

```swift
public enum AppUpdateAvailability: Equatable {
    case upToDate
    case available(AppRegistryEntry)
    case blockedMacOS(required: String)
}

public enum AppUpdate {
    public static func availability(
        running: String,
        registry: AppRegistryEntry,
        osMajor: Int,
        osMinor: Int
    ) -> AppUpdateAvailability
}
```

Compare `running` vs `registry.version` with `PackageGates.isValidSemVer` + `compareSemVer` (same as `AddonUpdate`). Parse `minMacOS` as `major.minor` (ignore patch). If OS is older, return `.blockedMacOS` even if the zip is newer.

- [ ] **Step 2:** Implement until tests pass.

### 1.3 Skip rules

**Files:** Create `shell/Sources/JugnuCore/Install/AppUpdateSkip.swift`; Test: `AppUpdateSkipTests.swift`

```swift
public struct AppUpdateSkip {
    /// App zip check (launch). True → do not fetch app registry.
    public static func shouldSkipAppCheck(
        firstRunCompleted: Bool,
        screenshotMode: Bool,
        bundlePath: String,
        env: [String: String],
        isDebug: Bool
    ) -> Bool

    /// Addon bulk on launch. True → do not fetch addon catalog for bulk.
    public static func shouldSkipAddonLaunchCheck(
        firstRunCompleted: Bool,
        screenshotMode: Bool
    ) -> Bool
}
```

Skip app check when: `!firstRunCompleted` OR `screenshotMode` OR `isDebug` OR `bundlePath` contains `.build/` or `DerivedData` OR `env["JUGNU_SKIP_APP_UPDATE"]` is non-empty. Do **not** skip merely because dest is unwritable here (phase 3: launch silent-skip if unwritable; manual check explains).

Skip addon launch check when: `!firstRunCompleted` OR `screenshotMode` only.

- [ ] **Step 1:** Table-driven tests for each flag.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** `cd shell && swift test` green. Phase 1 Done.

---

## Phase 2 — Download, gates, thin helper (fixture zip)

**Ships:** Core can turn a verified zip into a staged `Jugnu.app` + helper script. No App confirm yet. Tests use a fixture zip, not GitHub.

### 2.1 Paths + recover

**Files:** Modify `Paths.swift`; Modify `AddonInstaller.recoverInstallOrphans()`.

```swift
public var appUpdateDir: URL {
    stateDir.appendingPathComponent("app-update")
}
public var appUpdateStagingDir: URL {
    appUpdateDir.appendingPathComponent(".staging")
}
```

- [ ] **Step 1:** Add paths.
- [ ] **Step 2:** `recoverInstallOrphans` also `AtomicCommit.recoverOrphans(stagingParent: paths.appUpdateStagingDir, trashParent: paths.appUpdateDir.appendingPathComponent(".trash"))` **or** a dedicated wipe of `appUpdateStagingDir` (spec: delete `app-update/.staging/**` on launch). Prefer reusing `AtomicCommit.recoverOrphans` if the trash layout matches; otherwise `FileManager.removeItem` on `.staging` contents. Test: leftover staging dir is gone after recover.

### 2.2 Find bundle + gates

**Files:** Create `AppPackage.swift`; Test: `AppPackageTests.swift`

```swift
public enum AppPackage {
    /// Exactly one `Jugnu.app` at extract root or one child directory that contains it.
    public static func findAppBundle(in extractRoot: URL) throws -> URL

    public static func check(
        bundle: URL,
        expectedVersion: String,
        expectedBundleId: String = "app.jugnu.shell"
    ) throws
}
```

`findAppBundle`: if `extractRoot/Jugnu.app` is a directory, return it. Else exactly one child dir that contains `Jugnu.app`. Else throw `AppUpdateError.bundleIdentity`.

`check`:
1. `Info.plist` `CFBundleIdentifier` == expected; `CFBundlePackageType` == `APPL` (or missing package type is OK if identifier matches — require identifier).
2. `CFBundleShortVersionString` == `expectedVersion` else `versionMismatch`.
3. Executable: `Contents/MacOS/` + `CFBundleExecutable`. Run `PackageGates.checkEntrypoint(kind: "exec", fileURL:)` — thin Mach-O → `nonUniversalBinary` (map in UserFacingError; can reuse `AddonInstallerError.nonUniversalBinary` or wrap).

Identity tests: build a fake `.app` tree with `Info.plist` (no real Mach-O). Call identity checks via a `checkIdentity` helper tested without lipo. Universal test: reuse `PackageGatesTests` script file — `#` `!` shebang **passes** `checkEntrypoint`; for thin Mach-O refusal, if no fixture binary exists, test `PackageGates.checkEntrypoint` already covers it — `AppPackage.check` must call that same function on the executable URL.

- [ ] **Step 1:** Failing tests for multi-root, missing app, wrong id, version mismatch.
- [ ] **Step 2:** Implement find + identity/version. Wire `checkEntrypoint` for the executable when the file exists.

### 2.3 Installer (download + hash + extract)

**Files:** Create `AppInstaller.swift`; Test: `AppInstallerTests.swift`

```swift
public struct AppInstaller: Sendable {
    public var paths: JugnuPaths
    public var downloads: any InstallDownloading

    public init(paths: JugnuPaths, downloads: any InstallDownloading = AllowlistedDownloadSession())

    /// Returns the staged `Jugnu.app` URL. Does not spawn the helper.
    public func stage(entry: AppRegistryEntry) async throws -> URL
}
```

Flow: allowlisted download of `entry.url` → `requireSHA256` (copy the private hash helper from `AddonInstaller` into a shared `InstallHash.requireSHA256` **or** duplicate the 8-line CryptoKit check in `AppInstaller` — do not add a skip path) → extract into `appUpdateStagingDir/<uuid>/` via `ZipExtractor.extract` → `findAppBundle` → `AppPackage.check`. Return bundle URL. On any throw, delete that staging uuid dir.

Zip-slip: `ZipExtractor` already rejects `../`. One `AppInstaller` test with a slip zip (copy pattern from `ZipExtractor` / `AddonInstallerTests`) is enough to prove the call site uses it.

- [ ] **Step 1:** Failing tests: sha256 mismatch; slip zip; version mismatch after extract.
- [ ] **Step 2:** Implement `stage`.
- [ ] **Step 3:** Map remaining `AppUpdateError` / installer errors in `UserFacingError` (dest not writable comes in phase 3).

### 2.4 Helper script (bytes only)

**Files:** Create `AppApplyHelper.swift`; Test: `AppApplyHelperTests.swift`

```swift
public enum AppApplyHelper {
    /// Writes `apply.sh` + `plan.json` under `dir` (must be outside the bundle being replaced).
    public static func write(dir: URL, pid: Int32, sourceApp: URL, destApp: URL) throws -> URL
}
```

Script (POSIX, `/bin/sh`):
- Loop `kill -0 $PID` with a bounded wait (e.g. 60 × 0.25s); if still alive, exit 1 without `ditto`.
- `ditto` source onto dest.
- `xattr -dr com.apple.quarantine` dest (ignore failure).
- `open` dest.
- `rm -rf` staging parent of source (the uuid dir).

`write` returns the `apply.sh` URL. Assert: script path is under `dir`, not under `destApp`. Assert script contains `ditto` and the dest path.

Do **not** spawn the script in Core tests.

- [ ] **Step 1:** Tests for write location + required commands in script body.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** `cd shell && swift test` green. Phase 2 Done.

---

## Phase 3 — Yaml, prefs, menu, launch check, app confirm

**Ships:** User can turn keep-app off; Check for Updates prompts; Later does not download; confirm then `stage` + write helper + quit.

### 3.1 Config keys

**Files:** Modify `Models.swift` `ShellConfig`; Test: `ConfigStoreTests.swift`

```swift
public var keepAppCurrent: Bool
public var keepAddonsCurrent: Bool
// CodingKeys: keep_app_current, keep_addons_current
// decodeIfPresent ?? true
```

- [ ] **Step 1:** Tests: omitted keys → both `true`; round-trip false.
- [ ] **Step 2:** Implement encode/decode/init defaults `true`.

### 3.2 Confirm copy

**Files:** Create `AppUpdateConfirmation.swift`; Test: `AppUpdateConfirmationTests.swift`

```swift
public func confirmAppUpdateUI(version: String, notes: String?) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Update Jugnu?",
        message: notes.map { "Jugnu \(version) is ready. Update and restart?\n\n\($0)" }
            ?? "Jugnu \(version) is ready. Update and restart?",
        confirmLabel: "Update and Restart",
        cancelLabel: "Later"
    )
}
```

- [ ] **Step 1:** Assert labels and title.
- [ ] **Step 2:** Implement.

### 3.3 Coordinator + menu + prefs

**Files:**
- Create: `shell/App/KeepCurrentCoordinator.swift`
- Modify: `MenuBarController.swift` — add `onCheckForUpdates: (() -> Void)?` on the **normal** menu, item title `Check for Updates…`, placed above Quit (after the separator that already precedes Quit). Recovery menu: no item.
- Modify: `PrefsView.swift` — **Updates** section: two toggles bound to `model.config.shell.keepAppCurrent` / `keepAddonsCurrent` via `saveConfig`; caption with `ShellVersion.current`; button **Check for Updates** calling the same coordinator method as the menu.
- Modify: `JugnuApp.swift` / `MenuBarController` init call sites (`AppDelegate` + tests).
- Test: `shell/Tests/JugnuAppTests/MenuBarControllerTests.swift` (or existing) — normal menu contains `Check for Updates…`; recovery menu does not.
- Test: `KeepCurrentCoordinator` skip/order with a fake registry — prefer extracting the **decision** into Core (`AppUpdateSkip` + `AppUpdate.availability`) already tested; App test: `MenuBarController.menuItemTitles`.

```swift
@MainActor
final class KeepCurrentCoordinator {
    let model: AppModel
    let shellHost: ShellHost
    var onApplyAppUpdate: (URL) -> Void  // AppDelegate: write helper, killAll, spawn, terminate

    func checkOnLaunch() async
    func checkManual() async
}
```

`checkOnLaunch`:
1. If `AppUpdateSkip.shouldSkipAppCheck(...)` (pass `#if DEBUG`, `Bundle.main.bundlePath`, `ProcessInfo.processInfo.environment`, `model.state.firstRunCompleted`, `ScreenshotMode.isActive`) → skip app.
2. Else if `model.config.shell.keepAppCurrent`, fetch app registry; on error **return** (silent). If `.available` and dest writable (`FileManager.isWritableFile(atPath: Bundle.main.bundleURL.path)` — if the `.app` itself isn’t writable, skip silent on launch): `presentAppConfirm`. Do not `stage` until confirm.
3. Addon bulk is phase 4 — call a stub `checkAddonsOnLaunch()` empty in this phase.

`checkManual`:
- Always fetch (ignore keep flags for **detection**). Errors → `UserFacingError` on prefs banner **or** `PanelErrorBanner` via `shellHost` toast error. If `.upToDate` and no addon work (phase 4), toast “You’re up to date.”
- If dest not writable: show `UserFacingError` for `AppUpdateError.destNotWritable` (“Jugnu can’t replace itself here. Move it to Applications and try again.”).
- Present confirm; on confirm: `AppInstaller.stage` then `onApplyAppUpdate(stagedApp)`.

Present confirm: `shellHost.pushFollowUp(ui: confirmAppUpdateUI(...), commandId: "shell.app-update", ...)` then `orderFront` + `armClickOutsideDismiss` like `pushCatalog`. Follow-up success path stages+apply. Cancel / Later: no download.

`onApplyAppUpdate` in AppDelegate:
1. `AppApplyHelper.write(dir: model.paths.appUpdateDir, pid: ProcessInfo.processInfo.processIdentifier, sourceApp: staged, destApp: Bundle.main.bundleURL)`
2. `processHost.killAll()` (0057 quit path)
3. `Process` run `/bin/sh` with the script URL
4. `NSApp.terminate(nil)`

- [ ] **Step 1:** Menu titles test.
- [ ] **Step 2:** Wire coordinator; launch `Task` at **end** of `applicationDidFinishLaunching` after menu bar + hotkey (normal path only, not recovery). Never from palette show.
- [ ] **Step 3:** Prefs Updates section + mappings for `destNotWritable` / `helperSpawnFailed`.
- [ ] **Step 4:** `cd shell && swift test` green. Phase 3 Done.

---

## Phase 4 — Addon bulk

**Ships:** Launch (if keep-addons) and manual check offer one confirm, then sequential 0058 `install`.

### 4.1 Diff

**Files:** Create `AddonBulkUpdate.swift`; Test: `AddonBulkUpdateTests.swift`

```swift
public enum AddonBulkUpdate {
    public static func outdated(
        installed: [String: String],
        catalog: [RegistryEntry]
    ) -> [RegistryEntry]
}
```

Include entry when `AddonUpdate.isAvailable(installed: installed[id], registry: entry.version)`. Order: catalog order.

- [ ] **Step 1:** Tests: none, one, mixed, invalid versions skipped.
- [ ] **Step 2:** Implement.

### 4.2 Confirm + coordinator

**Files:** Create `AddonBulkConfirmation.swift`; Test: `AddonBulkConfirmationTests.swift`; Modify `KeepCurrentCoordinator`.

```swift
public func confirmAddonBulkUI(count: Int) -> UIDescriptor {
    UIDescriptor(
        pattern: .confirm,
        title: "Update addons?",
        message: "\(count) addons have updates. Update all?",
        confirmLabel: "Update",
        cancelLabel: "Later"
    )
}
```

Coordinator order (spec): **app confirm first**. If user Update-and-Restarts, do not present addon bulk this launch. If Later (or no app update), then addon bulk when `keepAddonsCurrent` (launch) or always (manual).

Launch addon errors: silent. Manual: `UserFacingError`.

On addon confirm: for each `RegistryEntry` in the outdated list:
```
guard ReplaceWhileTracked.proceed(...) else { continue }
let preserve = model.config.addons[id]?.enabled ?? false
try await model.installer.install(entry:enable:catalog:installedVersions:confirmDependencies:)
try? model.bootstrapDaemons(id:)
```
Catch: set a status naming the addon (`UserFacingError` + name); **continue**. Catalog Update path stays unchanged.

Manual with zero app + zero addon updates: toast “You’re up to date.”

- [ ] **Step 1:** Confirm copy test.
- [ ] **Step 2:** Wire sequential install; keep-addons **off** → launch skips bulk; catalog Update still works (existing tests).
- [ ] **Step 3:** `cd shell && swift test` green. Phase 4 Done.

---

## Phase 5 — Two-step first-run + docs

**Ships:** Wizard step 1 keep flags; step 2 checkbox catalog; Skip rules; Browse after close.

### 5.1 First-run UI + model

**Files:** Modify `FirstRunWindow.swift`, `AppModel.completeFirstRun`, `JugnuApp.swift` first-run `onDone`.

`completeFirstRun` becomes:

```swift
func completeFirstRun(
    keepAppCurrent: Bool,
    keepAddonsCurrent: Bool,
    useCommandSpace: Bool,
    selectedAddonIDs: [String],
    localAddonRoots: [URL]
) async throws
```

Writes `keep_*` yaml first. If `selectedAddonIDs` non-empty: `installFromRegistry(ids:)` with local fallback **only for ids that exist on disk** (today’s `recommendedLocalRoots` generalized: scan the same candidate bases for each selected id). Empty selection: install nothing. Always `state.firstRunCompleted = true`.

`FirstRunView`: `@State page: Int` 1|2.

Step 1: toggles keep app (default on), keep addons (default on), ⌘Space (default off, same Spotlight caption). Buttons **Continue** / **Skip**. Skip sets both keep flags **true**, ⌘Space **false**, goes to page 2.

Step 2: load catalog via `RegistryClient().fetchWithCache` (same cache file as browse). List `name` + `summary` with checkbox; pre-check `entry.tags.contains("recommended")`; if no row has that tag, pre-check `ShellConfig.recommendedAddonIDs`. **Continue** installs checked. **Skip** installs []. Window grows (~640×520 is enough; not viewB chrome).

Traffic-light close: treat as Skip on the **current** page then finish (page 1 close → both keep true, no extra addons; page 2 close → keep flags already written if they visited step 1, selected ids empty). Implement `NSWindowDelegate.windowShouldClose` on the controller.

After `completeFirstRun`: `onDone` in AppDelegate registers hotkey, `pushCatalog()`, nil firstRun.

- [ ] **Step 1:** Unit-test a pure helper `FirstRunSelection.precheckedIDs(entries:fallback:)` → recommended tags else fallback ids.
- [ ] **Step 2:** Rewrite `FirstRunView` + `completeFirstRun`; delete the third hardcoded list in the view (only `recommendedAddonIDs` as fallback).
- [ ] **Step 3:** AppDelegate `onDone` calls `pushCatalog()`.
- [ ] **Step 4:** Tests for `completeFirstRun` writing keep flags with a temp `HOME` (follow `AppModel` / installer test patterns). If UI tests are too heavy, Core helper + config tests are the gate; walk smoke for the window.

### 5.2 Docs

- [ ] **Step 1:** `PRIVACY.md` network: shell may fetch the **app registry** and release assets when keep-current is on or the user checks for updates.
- [ ] **Step 2:** `registry/README.md` — document `jugnu-app.json` fields.
- [ ] **Step 3:** `docs/release-process.md` Shell Release: zip `Jugnu.app` (universal), sha256, publish GitHub Release `shell-vX.Y.Z`, update `registry/jugnu-app.json` `version`/`url`/`sha256`. Never silently replace a published zip.
- [ ] **Step 4:** `CHANGELOG.md` Unreleased Added — one line: keep-current (app + addons) and two-step first-run.
- [ ] **Step 5:** Append **Manual — keep current (0063)** to `docs/architecture/shell-smoke.md`:

```
- [ ] First launch: step 1 defaults on; Skip still leaves both on; step 2 recommended pre-checked; Skip installs nothing and Browse opens
- [ ] Continue step 2 installs checked addons (including a non-recommended if checked)
- [ ] Preferences → Updates toggles persist in jugnu.yaml
- [ ] Menu Check for Updates… with matching 0.1.0 registry: “You’re up to date.”
- [ ] Later on an app prompt does not download; next launch prompts again
- [ ] Keep-addons on + outdated catalog row: bulk confirm; Cancel downloads nothing; catalog per-card Update still works with keep-addons off
```

- [ ] **Step 6:** Tickets **0017, 0004, 0062, 0063** → Done with spec/plan links when all phases are green (do this only at epic close).
- [ ] **Step 7:** `cd shell && swift test` green. Phase 5 Done.

---

## Spec coverage

| Spec | Task |
|---|---|
| §1 product locks | 3.2, 3.3, 4.2, 5.1 |
| §3 pipeline / not AddonInstaller | 2.3 |
| §4 registry JSON | 1.1 |
| §5 yaml + skip + timing | 1.3, 3.1, 3.3 |
| §6 thin helper in-place | 2.4, 3.3 `onApplyAppUpdate` |
| §7 addon bulk | 4.1–4.2 |
| §8 surfaces | 3.3, 5.1 |
| §9–10 errors/privacy | 1.1, 2.3, 5.2 |
| §11 phases | this plan’s phase headers |
| §12 tests | each phase’s tests |
| §13 docs | 5.2 |
| Signing/Sparkle non-goals | Global constraints |
