# Contributing to Jugnu

## Before You Start

Read [AGENTS.md](AGENTS.md), [.github/instructions/jugnu.instructions.md](.github/instructions/jugnu.instructions.md), and the relevant documents under [docs/](docs/). Preserve user changes and keep unrelated refactors out of focused work.

Jugnu follows the hierarchy **Category -> Addon -> Commands**. An addon is one installable zip for one user job; related commands and UI belong inside that addon.

## Development Workflow

1. Inspect the owning implementation, nearby tests, backlog item, and architecture document before editing.
2. State the expected behavior and choose a cheap check that could disconfirm it.
3. Make the smallest coherent change.
4. Run focused validation immediately after each edit.
5. Update the owning documentation, manifest, backlog entry, or changelog when behavior changes.
6. Run the broader checks before opening a pull request.

Do not scaffold an addon until its packaging boundary is explicit. Addon payloads must not be bundled inside `Jugnu.app`, and published addons must not require user-installed Python or Homebrew.

## Local Checks

Python checks are managed with `uv`:

```bash
uv sync
make lint
make typecheck
make spell
make test
make ci
```

Swift package checks run from `shell/`:

```bash
cd shell
swift format --in-place --recursive Sources Tests TestsExtended
swift lint Sources Tests TestsExtended
swift test
```

The `swift format` and `swift lint` commands require the Swift toolchain's format/lint plugins or equivalent installed tools. When those commands are unavailable, run `swift test` and report the missing tooling rather than silently skipping validation.

Less-frequent live registry/install checks (network, real side effects; not CI):

```bash
make test-extended
```

For macOS app smoke testing, quit any running Jugnu, then:

```bash
make run
```

Use the checklist in [docs/architecture/shell-smoke.md](docs/architecture/shell-smoke.md). Details: [README — Run locally](README.md#run-locally).

## Swift Conventions

- Keep `JugnuCore` independent from UI concerns; keep AppKit and SwiftUI code in the UI/app targets.
- Match the Swift version and macOS deployment target in `shell/Package.swift`.
- Prefer value types, explicit Codable models, small protocols, and dependency injection at filesystem, process, clock, network, and clipboard boundaries.
- Use structured concurrency and keep UI mutations on `MainActor`.
- Do not block the main actor with filesystem, process, archive, network, or addon work.
- Avoid force unwraps and force casts in product code.
- Propagate errors; do not discard process failures, decoding errors, cleanup failures, or permission failures.
- Validate addon paths and manifest fields, and prevent archive path traversal.
- Keep latency visible in design and tests; target the budgets in [the addon UI and speed design](docs/architecture/2026-08-22-addon-ui-speed-design.md).

## Pull Requests

A pull request should explain the user-facing behavior, affected architecture boundary, validation run, and any permissions or platform limitations. Keep commits and changes focused. Do not include secrets, generated build output, `.build/`, or local configuration.

## Changelog Convention

Add one dated, single-line entry to `CHANGELOG.md` for each user-visible app, tool, addon, or documentation change. Use the date format `YYYY-MM-DD`, place the entry under the appropriate `Unreleased` subsection, and describe the result rather than the implementation detail.
