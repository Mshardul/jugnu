# Jugnu backlog

Status legend for staged leaves: **active** = runnable code; **stub** = README only; **icebox** / **later** = defer.

## Platform (build order)

| Priority | Item | Notes |
|---|---|---|
| 1 | Shell + YAML addon enablement | Design before scaffold — see `docs/architecture/` |
| 2 | Dual clipboard modes | Ephemeral vs history; privacy-aware; build on `apps/clipboard-history` |
| 3 | Robust window management | Absorb `window-layouts` / `layout-save` stubs into a real first-party addon |

## Gap list (keep / build)

Not yet staged as leaves. Candidates after shell MVP:

1. Audio output switcher
2. Caffeine / keep-awake
3. Webcam mute
4. AirPods / BT battery bar
5. Claude/agent mission control (lite)
6. Dev-server / common-ports bar
7. Screenshot inbox
8. Paste plain / strip formatting (or fold into paste-transform)
9. Kill hung app picker
10. Disk pressure bar

## Staged leaves — `apps/`

| Leaf | Status | Role for Jugnu |
|---|---|---|
| clipboard-history | active | Core input for clipboard addon |
| battery-eta | active | Menu-bar / status candidate |
| brew-outdated | active | Dev-ops menu bar |
| floating-note | active | First-party QoL |
| pomodoro | active | First-party QoL |
| weather-bar | active | Menu-bar candidate |
| world-clock | active | Menu-bar / palette |
| tools-palette | stub | Nursery CLI runner — evolves into shell search surface or thin addon |
| window-layouts | stub | Fold into window-management addon |
| layout-save | stub | Fold into window-management addon |
| meeting-bar | stub | Meeting/device QoL |
| paste-transform | stub | Paste plain / transforms |
| port-picker | stub | Dev-ops; may wrap Tools `port-tool` |
| trash-ui | stub | May wrap Tools `trash` |
| color-eyedropper | stub | Utility addon |
| qr-clip | stub | May wrap Tools `qr-encode` |
| downloads-triage | stub | File triage |
| repo-jumper | stub | Dev QoL |
| ssh-host-picker | stub | Dev QoL |
| app-launcher | stub / icebox | Ecosystem war; Jugnu *is* the launcher |

## Staged leaves — `extensions/macos/`

| Leaf | Status | Role for Jugnu |
|---|---|---|
| airdrop-folder | active | Finder / share QoL |
| focus-toggle | active | Meeting/device QoL |
| mic-mute | active | Meeting/device QoL |
| open-terminal-here | active | Dev QoL |
| quarantine-clear | active | File / Gatekeeper QoL |
| snippet-expand | stub / later | Prefer clipboard/hotkey paste first |

## Related Tools CLIs (stay in Tools)

Integrate as addons/dependencies; do not rewrite unless needed:

`port-tool`, `trash`, `pb`, `notify`, `qr-encode`, `color-convert`, `file-snippets`, and other nursery CLIs.

Claude usage / session tools: include only if explicitly moved; not currently in this repo.

## Out of scope rabbit holes

- Day-one Alfred-class general file search (unless designing shell search)
- Merging Tools into Jugnu
- Accessibility-heavy snippet expand before paste paths
