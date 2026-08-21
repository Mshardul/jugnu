# Jugnu vision

## Metaphor

*Jugnu* is Hindi for firefly. Not Apple’s floodlight (Spotlight) — a small personal light that appears when you call it.

**Tagline direction:** “A little light for everything on your Mac.” / “Glow when you call.”

## Product goal

A Mac **command platform** that can replace Spotlight + Alfred + Raycast for daily command, clipboard, window, and addon workflows — not a thin wrapper around someone else’s launcher.

## Naming

| Surface | Name |
|---|---|
| Display | Jugnu |
| GitHub repo | `jugnu` |
| CLI binary | `jugnu` (preferred) |

Do not invent a second product name or collapse the Tools nursery into Jugnu without an explicit decision.

## Decomposition (locked)

1. **Shell** — hotkey palette, search, addon loader, install/uninstall addons, enable/disable via YAML
2. **Clipboard** — two modes: use-and-throw vs full history; skip concealed pasteboard / password-manager markers
3. **Window management** — deep feature set and strong UX (not only a minimal layout saver)
4. **First-party addons** — meeting/device QoL, file triage, and similar focused jobs
5. **Dev ops in the menu bar** — yes (ports, brew, agents, disk, etc.)

## Addon model

- All-purpose shell; users install/uninstall addons
- Enable/disable in YAML
- Prefer focused addons over one binary of unrelated jobs
- Tools nursery (`cli/`, etc.) stays separate; Jugnu may wrap those tools as addons rather than merging source trees

## Relationship to Tools

Jugnu lives in its **own** repo. Staging leaves under `apps/` and `extensions/macos/` were moved or copied from Tools planning. Small independent CLIs remain in Tools unless graduated; Jugnu integrates them as dependencies/wrappers when needed.

## Explicit non-goals (early)

- Rebuilding a general file-search war with Alfred on day one (except as part of designing shell search)
- Merging unrelated Tools CLIs into one Jugnu binary
- TextExpander-class in-app snippet expand before clipboard/hotkey paste paths (Accessibility permission + latency)
