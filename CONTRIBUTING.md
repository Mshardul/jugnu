# Contributing to Jugnu

## Before You Start

Read [docs/conventions.md](docs/conventions.md) (coding standards), [AGENTS.md](AGENTS.md) if you are an agent, and the relevant documents under [docs/](docs/). Preserve user changes and keep unrelated refactors out of focused work.

Jugnu follows **Category → Addon → Commands**. An addon is one installable zip for one user job; related commands and UI belong inside that addon. Every change is judged by invoke → visible result — details in the conventions.

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

SwiftFormat and SwiftLint match CI. Install once (Homebrew), then lint or format:

```bash
make tools-swift      # brew install swiftformat swiftlint if missing
make lint-swift       # SwiftLint (installs via brew if missing)
make format-swift     # SwiftFormat in place (optional; not a pre-commit gate)
```

They also run on `git commit` via pre-commit (`make hooks` once): SwiftLint fails the commit if it reports errors. Do not skip when Swift files change.

Less-frequent live registry/install checks (network, real side effects; not CI):

```bash
make test-extended
```

For macOS app smoke testing, quit any running Jugnu, then:

```bash
make run
```

Use the checklist in [docs/architecture/shell-smoke.md](docs/architecture/shell-smoke.md). Details: [README — Run locally](README.md#run-locally).

## Pull Requests

A pull request should explain the user-facing behavior, affected architecture boundary, validation run, and any permissions or platform limitations. Confirm the [conventions review checklist](docs/conventions.md#review-checklist): reuse an existing type, or say why it is wrong. Keep commits and changes focused. Do not include secrets, generated build output, `.build/`, or local configuration.

## Changelog Convention

Add one dated, single-line entry to `CHANGELOG.md` for each user-visible app, tool, addon, or documentation change. Use the date format `YYYY-MM-DD`, place the entry under the appropriate `Unreleased` subsection, and describe the result rather than the implementation detail.
