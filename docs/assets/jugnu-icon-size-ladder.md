# Jugnu icon — per-size tuning reference

The [master SVG](jugnu-icon.svg) is correct at 1024/512/256/128px. Below 128px, naive rasterization loses the glow and trail — both need to grow *relative* to the canvas as rendered size shrinks. These are the exact tuned values verified legible during design (see [spec §3](../architecture/2026-08-23-palette-ui-product-pass.md)); use them directly rather than re-deriving new ones when generating the actual `.appiconset` PNGs.

All paths share viewBox `0 0 128 128`; only the numbers below change per target render size.

| Render size | Glow radius | Speck radius | Trail stroke-width | Trail dash pattern | Glow gradient stops (offset / color / opacity) |
|---|---|---|---|---|---|
| 256 / 128px | 32 | 6 | 3 | `1 6.5` | 0% `#fff`, 20% `#fff2d9`, 48% `#f5a623`, 80% `#c97a12` @ 0.45, 100% `#c97a12` @ 0 |
| 64px | 34 | 7 | 4 | `1 7` | 0% `#fff`, 22% `#fff2d9`, 50% `#f5a623`, 85% `#c97a12` @ 0.5, 100% `#c97a12` @ 0 |
| 48px | 36 | 8 | 4.5 | `1 7.5` | 0% `#fff`, 24% `#fff2d9`, 52% `#f5a623`, 88% `#c97a12` @ 0.55, 100% `#c97a12` @ 0 |
| 32px | 38 | 9 | 5.5 | `1 8` | 0% `#fff`, 26% `#fff2d9`, 56% `#f5a623`, 100% `#c97a12` @ 0.55 (no fully-transparent stop — glow fills more of the canvas) |
| 16px (menu bar / Dock small) | 40 | 10 | 7 | `1 9` | 0% `#fff`, 30% `#fff2d9`, 60% `#f5a623`, 100% `#c97a12` @ 0.6 |

Glow and speck stay centered at `cx=66 cy=58` in all sizes. Trail path start point moves slightly inward as stroke-width grows (e.g. `M20 106` at 256px → `M30 98` at 16px) so the thicker stroke doesn't overshoot the badge edge — see the working mockup for exact per-size path `d` values if regenerating by hand: [artifact link preserved in conversation history; re-derive from the table above if unavailable].

**Rule of thumb for any size not listed:** interpolate glow radius and stroke-width linearly between the nearest two rows; keep the speck-to-glow radius ratio roughly 1:4.
