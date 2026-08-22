# Security Policy

## Supported Versions

Jugnu is pre-release software. Security fixes are handled on the current default branch; published addon releases are supported according to their release notes.

## Reporting a Vulnerability

Do not open a public issue for a suspected vulnerability. Report it privately through the repository's configured GitHub security advisory contact, or contact the maintainers privately through the project owner.

Include:

- affected component, addon, or release;
- macOS version and installation method;
- reproduction steps or a minimal proof of concept;
- potential impact, especially involving command execution, archive extraction, permissions, clipboard data, or secrets.

Remove credentials, personal files, tokens, and other sensitive data from reports. The maintainer will acknowledge receipt, investigate, coordinate disclosure, and publish a correction when appropriate.

## Security Expectations

- Addons are executable code and should be installed only from trusted release assets.
- Registry checksums must match the exact addon zip before installation.
- Addon manifests and archive paths must be validated before use.
- Cleanup is restricted to paths declared by the addon and owned by that addon.
- Raw clipboard contents, screen captures, and credentials must not be added to logs or network requests.
- Permission requests must be explicit, minimal, and made at the point of use.
