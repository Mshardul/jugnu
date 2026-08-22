# Data Privacy Policy

Jugnu is designed as a local-first macOS command platform. This policy describes the intended behavior of the shell and first-party addons.

## Data Handling

- Commands run on the user's Mac unless a command explicitly needs a network service.
- Jugnu does not sell, rent, or use user data for advertising.
- The shell does not send clipboard contents, screen pixels, typed commands, file contents, or permission data to Jugnu servers by default.
- Context-aware features are opt-in, local, minimal, and disabled by default until explicitly enabled.
- Concealed pasteboard contents and password-manager markers must not be stored in clipboard history.
- Logs and diagnostics must avoid raw clipboard contents, credentials, tokens, private keys, and personal file contents.

## Permissions

Permissions are requested only when a feature needs them and should be explained at the point of use. An addon may require additional permissions, but it must document those requirements and provide a useful fallback where possible.

## Network Access

The shell may use the network to fetch the addon registry and release assets. Addons may use the network only when their documented job requires it. Network access should be visible in the addon documentation and should not transmit unrelated user data.

## Local Storage

Configuration and installed addons are stored in the user's configured macOS data directories. Addons must document persistent state and declare cleanup paths so disable and uninstall can remove addon-owned data deterministically.

## Changes and Contact

Privacy behavior is part of the product contract. Changes that affect collected, stored, or transmitted data must be documented in `CHANGELOG.md` and reviewed before release. Report privacy concerns privately using the process in [SECURITY.md](SECURITY.md).

This document describes the project's current design intent, not legal advice or a substitute for a jurisdiction-specific privacy notice.
