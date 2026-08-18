# -*- coding: utf-8 -*-
"""Chroma-key Lili sprites: remove black / studio-grey backdrops to alpha."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

CHARS = Path(r"C:\Users\Admin\Documents\channel_dream\dream-channel\cabin-slice\assets\ui\chars")


def dist(a, b) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def saturation(rgb) -> float:
    r, g, b = [c / 255.0 for c in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx < 1e-6:
        return 0.0
    return (mx - mn) / mx


def cutout(path: Path, bg: tuple[int, int, int], hard: float, soft: float, protect_sat: float = 0.12) -> None:
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            rgb = (r, g, b)
            # Keep colorful / character-looking pixels
            if protect_sat > 0 and saturation(rgb) >= protect_sat and dist(rgb, bg) > hard * 0.55:
                continue
            d = dist(rgb, bg)
            if d <= hard:
                px[x, y] = (r, g, b, 0)
                cleared += 1
            elif d < soft:
                t = (d - hard) / max(soft - hard, 1e-6)
                px[x, y] = (r, g, b, int(a * t))
                cleared += 1
    im.save(path)
    print(f"{path.name}: bg={bg} cleared~{cleared}")


def main() -> None:
    idle = CHARS / "lili_idle"
    for p in sorted(idle.glob("frame_*.png")):
        # Unity idle: solid black
        cutout(p, bg=(0, 0, 0), hard=28, soft=52, protect_sat=0.08)

    stand = CHARS / "SP_Lili_Stand.png"
    # GPT stand: mid studio grey ~#9a9c9f
    cutout(stand, bg=(154, 156, 159), hard=32, soft=52, protect_sat=0.10)
    print("done")


if __name__ == "__main__":
    main()
