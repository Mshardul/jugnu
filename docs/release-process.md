# Release Process

This process covers the native Jugnu shell and independently distributed addons.

## Versioning

- The shell and each addon use Semantic Versioning: `MAJOR.MINOR.PATCH`.
- Increment the major version for incompatible public behavior or protocol changes.
- Increment the minor version for backward-compatible features.
- Increment the patch version for backward-compatible fixes.
- Keep `api: 1` stable for compatible addon protocol changes.

## Shell Release

1. Confirm the working tree passes the relevant Python and Swift checks.
2. Run the macOS smoke checklist in [shell-smoke.md](architecture/shell-smoke.md).
3. Update `CHANGELOG.md` with dated, single-line entries and a release heading.
4. Build and verify the shell-only app; do not include addon payloads or zip files in `Jugnu.app`.
5. Publish the app using the repository's chosen distribution and signing process.

## Addon Packaging

Each addon is one installable zip with one clear user job. The package must contain a consistent root layout:

```text
<addon-id>/
  addon.yaml
  bin/run
  README.md
```

Before packaging:

1. Confirm the addon has an explicit boundary and belongs in the catalog; see [the manifest reference](addon-manifest.md).
2. Validate `addon.yaml`, including `id`, `version`, `api`, commands, entrypoint, and cleanup declarations.
3. Ensure the entrypoint does not require user-installed Python or Homebrew.
4. Test the JSON stdin/stdout contract with `api: 1`.
5. Test disable and uninstall cleanup, including declared paths and launchd labels.
6. Package only the addon source and runtime files; exclude tests, build output, credentials, and local configuration.
7. Create the zip with the repository packaging helper when available.
8. Calculate SHA-256 for the exact published zip.
9. Publish the zip as a GitHub Release asset.
10. Add or update the matching entry in `registry/addons.json`.

A registry entry must include the addon id, name, version, API version, release URL, SHA-256 checksum, and a concise summary. The registry must point to the exact immutable release asset whose checksum was calculated.

## Release Verification

After publishing:

- Download the release asset from its public URL.
- Recalculate SHA-256 and compare it with `registry/addons.json`.
- Unpack into a temporary addon directory and verify the root layout.
- Run a representative command and confirm a valid JSON response.
- Verify that install, enable, disable, update, and uninstall behavior matches the manifest cleanup declarations.
- Confirm the changelog and README links are current.

## Rollbacks and Corrections

Never silently replace a published asset. For a packaging or checksum error, publish a corrected patch release, update the registry to the new immutable asset, and document the correction in `CHANGELOG.md`. For a compromised or withdrawn addon, remove or disable its registry entry and document the action clearly.
