---
name: Jugnu project conventions
description: "Project conventions for Jugnu product, Swift shell, macOS integration, addons, testing, and documentation."
applyTo: "**/*"
---

# Jugnu Project Conventions

## Product Model

- Jugnu is a lightweight native macOS command platform: a hotkey palette, menu-bar surface, and installable addons.
- Preserve the user-facing hierarchy: **Category -> Addon -> Commands**.
- A Category is browse taxonomy only. An Addon is one installable zip and one enable key. Commands are actions inside an Addon.
- Name addons and commands for the user's job, not an invented scenario.
- Keep unrelated jobs in separate addons. Put related commands and UI in one addon when users would expect them together.
- Treat popup UI and speed as part of every addon. Context-aware surfacing is a later capability.

Read [docs/vision.md](../../docs/vision.md) for product intent and packaging rules.

## Architecture Boundaries

- `shell/` is the native Swift host. Keep it lightweight and divided into Core and UI responsibilities.
- Addon code and addon payloads never ship inside `Jugnu.app`.
- Published addons must not require user-installed Python or Homebrew.
- Addons communicate with the shell through JSON over stdin/stdout using `api: 1`.
- The shell owns palette, menu-bar, popup windows, hotkeys, lifecycle, cleanup, and UI patterns. Addons own job logic and system calls.
- Addons must declare cleanup for side effects so disable and uninstall are deterministic.
- `apps/` and `extensions/macos/` are staging inventory, not automatically shipped addons. Do not scaffold an addon until its packaging boundary is explicit.
- Use the approved architecture documents before changing shell or addon contracts:
  - [shell design](../../docs/architecture/2026-08-22-shell-design.md)
  - [addon UI and speed](../../docs/architecture/2026-08-22-addon-ui-speed-design.md)
  - [shell MVP plan](../../docs/superpowers/plans/2026-08-22-shell-mvp.md)

## Swift and macOS

- Target the Swift version and macOS deployment target declared by `shell/Package.swift`; do not raise either without a concrete requirement.
- Prefer clear value types, protocol-oriented boundaries, and small focused types. Keep Foundation and AppKit/SwiftUI responsibilities separated.
- Use `Codable` for JSON and configuration models. Keep external protocol models explicit and versionable.
- Prefer structured concurrency (`async`/`await`, task cancellation, actors where shared mutable state requires them) for asynchronous work. Keep UI updates on `MainActor`.
- Do not block the main thread with filesystem, network, process, archive, or addon work. Open shell UI promptly, then load or update content asynchronously.
- Propagate errors with typed or descriptive errors. Never discard failures from install, checksum verification, process execution, cleanup, permissions, or decoding.
- Use `URL`, `FileManager`, `Process`, and `Pipe` through small injectable boundaries so filesystem and process behavior can be tested without relying on a live Mac state.
- Validate paths and addon manifest fields before use. Prevent path traversal when unpacking archives and restrict cleanup to declared, addon-owned paths.
- Use `CryptoKit` for SHA-256 verification rather than an ad hoc implementation.
- Avoid force unwraps and force casts in product code. Use them only in tests when the failure would indicate a broken fixture.
- Make UI state explicit. Avoid unmanaged windows, hidden global state, and retain cycles. Use weak captures where a closure could retain an owning controller.
- Respect macOS permissions and privacy. Request permission at the point of use, explain why it is needed, and provide a usable fallback when possible.
- Respect reduced motion and system appearance. Keep visual chrome small, purposeful, and consistent with the shell design.

## Addon UI and Performance

- Use the smallest UI pattern that completes the job: `toast`, `confirm`, `list`, `form`, `progress`, or `status`.
- Addons return data; the shell owns windows, focus, dismiss behavior, theming, and motion.
- Treat latency as a product requirement, not a later optimization. Every implementation must protect the path from invocation to visible feedback.
- Do not let addon I/O, filesystem work, network requests, archive work, or process launches block first paint or freeze the main actor. Show panel chrome or progress before slow work.
- Target the approved budgets: hotkey to palette first paint <= 50 ms, command to toast <= 150 ms, command to panel chrome <= 100 ms, panel chrome to useful content <= 300 ms, and follow-up action to feedback <= 150 ms. Treat 100/400/200/800/400 ms respectively as hard ceilings unless the design explicitly justifies an exception.
- Keep cold-start paths small. Avoid unnecessary process launches, heavy runtime startup, synchronous dependency loading, and repeated setup on every command.
- Measure invocation, first paint, content, feedback, and dismissal timestamps locally. Use the measurements to find regressions rather than assuming that code is fast.
- Prefer cancellation, bounded work, cached indexes, incremental loading, and background tasks for slow or repeatable operations.
- Add tests or benchmarks for latency-sensitive paths when practical, including that the UI remains responsive while addon work is in progress.
- Preserve backward compatibility for toast responses such as `{ "ok": true, "message": "..." }`.
- Do not add screen capture or raw clipboard secrets to context. Context-aware behavior must remain opt-in and local.

## Testing and Validation

- Follow test-driven development for `JugnuCore` where practical: write a focused failing test, implement the smallest behavior, then rerun it.
- Test behavior at boundaries: YAML/JSON decoding, paths, command indexing, search, process execution, checksum verification, cleanup, permissions, and cancellation.
- Inject filesystem, process, clock, network, and clipboard dependencies when tests would otherwise depend on macOS state.
- Keep tests deterministic and platform-aware. Do not make Linux or CI tests require macOS commands such as `osascript`, `pbcopy`, `pmset`, or `shortcuts`.
- Run the narrowest relevant test immediately after each edit, then run the broader suite when the slice is stable.
- Swift package checks run from `shell/` with `swift test` (same command as CI). Live registry tests are `make test-extended`.
- Python checks use the repository commands in `Makefile`: `make lint`, `make typecheck`, `make spell`, `make test`, and `make ci`.
- Run formatting and spelling checks for changed documentation and code.

## Documentation and Change Discipline

- Update the owning design document, backlog, README, or addon manifest when behavior or packaging changes.
- Keep public interfaces and protocol changes minimal and documented.
- Before editing, inspect nearby implementations, tests, and current user changes. Form one local hypothesis and identify a cheap check that could disconfirm it.
- Make the smallest coherent edit. Do not reformat unrelated files or perform opportunistic refactors.
- Preserve changes you did not make. Never reset, checkout, or otherwise discard user work.
- Do not create commits, branches, or worktrees unless the user explicitly requests the specific Git action.
- Report what changed, what was validated, and any remaining risks. Never claim an item is complete without executable validation when the environment provides it.
