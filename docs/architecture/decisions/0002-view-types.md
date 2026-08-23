# ADR 0002 — Shell-owned view types, not per-addon geometry

**Status:** Accepted  
**Date:** 2026-08-24  
**Spec:** [2026-08-24 view types](../2026-08-24-view-types.md)

## Context

Addons need search-strip, ~40% week/board, and ~70% sit-in canvases, on laptops and external / ultrawide / portrait monitors. 0008 forbids per-addon pixel sizes so the catalog does not become a pile of one-off frames.

## Decision

The shell publishes a **fixed catalog of ten view-type ids**. Addons **allow-list** ids and pick one per command/UI. Size is a function of the **current screen’s `visibleFrame`**, then min/max point clamps. Panel aspect (portrait vs landscape) is the viewport, not device rotation.

## Consequences

- One `KeyablePanel` still morphs; no second host.
- Validator will reject unknown ids and pixel fields.
- `board` / `spread` / `canvas` do not dismiss on click-outside; other in-panel types do.

## Alternatives rejected

- Percent or width/height in addon yaml  
- Always-large panel with a small search inside  
- Off-screen fake workspaces as a view type  
