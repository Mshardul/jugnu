# ADR 0001: JSON Addon Boundary

- Status: Accepted
- Date: 2026-08-22

## Context

Jugnu needs installable addons without placing addon code inside the native shell. Addons may use different implementation languages and system tools, while the shell must retain control of lifecycle, UI, permissions, and cleanup.

## Decision

Addons run as external entrypoints and communicate with the shell through JSON over stdin/stdout using `api: 1`. The shell owns addon discovery, command indexing, process lifecycle, UI, timeout behavior, and declared cleanup. Addons own job logic and system calls.

Each addon is distributed as one zip with an `addon.yaml` manifest. Published addons must not require a user-installed Python runtime or Homebrew.

## Consequences

- The shell remains small and language-independent.
- Addon failures can be isolated and represented as structured errors.
- Addon processes have startup and serialization costs, so latency must be measured and protected with timeouts and fast UI feedback.
- Manifest validation and archive path safety are required at install time.
- Rich UI is shell-owned and uses declarative JSON patterns rather than arbitrary addon windows.

## Alternatives Considered

- In-process plugins were rejected because they increase crash, signing, trust, and versioning risk.
- Arbitrary HTML/JavaScript addon views were deferred because they add startup cost and inconsistent UI behavior.
- A single bundled binary was rejected because it violates independent addon installation and keeps the shell coupled to addon code.
