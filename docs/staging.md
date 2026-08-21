# Staging inventory

`apps/` and `extensions/macos/` at the repo root are the **staging inventory** for Jugnu: implemented CLIs/apps and planned stubs moved from Tools planning.

They stay at these paths until the addon contract is real (avoids a rename churn). Graduation path:

1. Shell + YAML loader exists
2. Leaf gets a thin addon wrapper under `addons/` (or is rewritten as a first-party addon)
3. Stub-only leaves may be deleted or rewritten in place once their parent subsystem (e.g. window management) owns the feature

Do not treat every stub README as a shipped Jugnu feature.
