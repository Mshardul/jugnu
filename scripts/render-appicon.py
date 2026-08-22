#!/usr/bin/env python3
"""Emit per-size Jugnu icon SVGs using the size-ladder table (not naive downsample)."""

from __future__ import annotations

import argparse
from pathlib import Path

# Render size → (glow_r, speck_r, stroke, dash, trail_d, stops)
# stops: (offset_pct, color, opacity|None)
LADDER = {
    16: (
        40,
        10,
        7,
        "1 9",
        "M30 98 Q 46 74 66 58",
        [(0, "#ffffff", None), (30, "#fff2d9", None), (60, "#f5a623", None), (100, "#c97a12", 0.6)],
    ),
    32: (
        38,
        9,
        5.5,
        "1 8",
        "M28 100 Q 45 75 66 58",
        [(0, "#ffffff", None), (26, "#fff2d9", None), (56, "#f5a623", None), (100, "#c97a12", 0.55)],
    ),
    48: (
        36,
        8,
        4.5,
        "1 7.5",
        "M26 102 Q 44 76 66 58",
        [
            (0, "#ffffff", None),
            (24, "#fff2d9", None),
            (52, "#f5a623", None),
            (88, "#c97a12", 0.55),
            (100, "#c97a12", 0),
        ],
    ),
    64: (
        34,
        7,
        4,
        "1 7",
        "M24 104 Q 43 77 66 58",
        [
            (0, "#ffffff", None),
            (22, "#fff2d9", None),
            (50, "#f5a623", None),
            (85, "#c97a12", 0.5),
            (100, "#c97a12", 0),
        ],
    ),
}


def _stops(rows: list[tuple[int, str, float | None]]) -> str:
    parts = []
    for offset, color, opacity in rows:
        extra = "" if opacity is None else f' stop-opacity="{opacity}"'
        parts.append(f'      <stop offset="{offset}%" stop-color="{color}"{extra}/>')
    return "\n".join(parts)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    import struct
    import zlib

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = b"".join(b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    )


def write_template_png(path: Path, pixel_size: int = 32) -> None:
    """Menu-bar template: two black circles, alpha only (matches jugnu-icon-template.svg)."""
    scale = pixel_size / 128.0
    cx, cy = 66 * scale, 58 * scale
    glow_r, speck_r = 40 * scale, 11 * scale
    pixels = bytearray(pixel_size * pixel_size * 4)
    for y in range(pixel_size):
        for x in range(pixel_size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            dist = (dx * dx + dy * dy) ** 0.5
            alpha = 0.0
            if dist < glow_r:
                edge = max(0.0, min(1.0, glow_r - dist))
                alpha = max(alpha, 0.5 * edge)
            if dist < speck_r:
                edge = max(0.0, min(1.0, speck_r - dist))
                alpha = max(alpha, edge)
            a = int(round(min(1.0, alpha) * 255))
            i = (y * pixel_size + x) * 4
            pixels[i : i + 4] = bytes((0, 0, 0, a))
    write_png(path, pixel_size, pixel_size, bytes(pixels))


def svg_for(size: int) -> str:
    glow_r, speck_r, stroke, dash, trail_d, stops = LADDER[size]
    # Intrinsic size stays large so Quick Look does not pad a tiny SVG into a white thumbnail.
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="1024" height="1024">
  <defs>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
{_stops(stops)}
    </radialGradient>
    <linearGradient id="trail" x1="66" y1="58" x2="30" y2="98" gradientUnits="userSpaceOnUse">
      <stop offset="0%" stop-color="#fff2d9"/>
      <stop offset="50%" stop-color="#f5a623"/>
      <stop offset="100%" stop-color="#f5a623" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="28" fill="#16130e"/>
  <path d="{trail_d}" stroke="url(#trail)" stroke-width="{stroke}"
        stroke-linecap="round" fill="none" stroke-dasharray="{dash}"/>
  <circle cx="66" cy="58" r="{glow_r}" fill="url(#glow)"/>
  <circle cx="66" cy="58" r="{speck_r}" fill="#0c0906"/>
</svg>
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("outdir", type=Path)
    args = parser.parse_args()
    args.outdir.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 48, 64):
        (args.outdir / f"jugnu-icon-{size}.svg").write_text(svg_for(size), encoding="utf-8")
    write_template_png(args.outdir / "MenuBarIcon.png", 32)


if __name__ == "__main__":
    main()
