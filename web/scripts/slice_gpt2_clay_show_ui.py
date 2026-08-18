#!/usr/bin/env python3
"""Slice GPT Image 2 clay-show atlases into transparent UI PNG assets."""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


REPO = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO / "cabin-slice" / "assets" / "ui" / "generated" / "gpt2_clay_show_v1"
SLICE_DIR = SOURCE_DIR / "slices"
AUDIT_DIR = REPO / "downloads" / "clay-cartoon-ui-audit"


ASSET_INFO = {
    "paper_stage_frame": {
        "source": "gpt2_clay_show_paper_atlas_v1.png",
        "classification": "widest",
        "usage": "9-slice",
        "recommended_for": ["battle stage outer frame", "large dialog panel"],
        "slice_insets": [110, 86, 110, 86],
    },
    "paper_popup_frame": {
        "source": "gpt2_clay_show_paper_atlas_v1.png",
        "classification": "remaining",
        "usage": "9-slice",
        "recommended_for": ["omen modal", "inventory or portrait panel"],
        "slice_insets": [58, 54, 58, 54],
    },
    "paper_ticket_card": {
        "source": "gpt2_clay_show_paper_atlas_v1.png",
        "classification": "portrait",
        "usage": "fixed",
        "recommended_for": ["reward card", "name or item ticket"],
        "slice_insets": None,
    },
    "paper_tape_strip": {
        "source": "gpt2_clay_show_paper_atlas_v1.png",
        "classification": "smallest",
        "usage": "fixed",
        "recommended_for": ["temporary hint", "decorative state label"],
        "slice_insets": None,
    },
    "clay_button_primary": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 0,
        "usage": "9-slice",
        "recommended_for": ["place room", "end turn", "primary CTA"],
        "slice_insets": [78, 58, 78, 58],
    },
    "clay_status_magenta": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 1,
        "usage": "9-slice",
        "recommended_for": ["enemy status", "special action label"],
        "slice_insets": [54, 42, 54, 42],
    },
    "clay_button_secondary": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 2,
        "usage": "9-slice",
        "recommended_for": ["rotate room", "secondary CTA"],
        "slice_insets": [78, 58, 78, 58],
    },
    "clay_status_teal": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 3,
        "usage": "9-slice",
        "recommended_for": ["player AP", "health or shield status"],
        "slice_insets": [54, 42, 54, 42],
    },
    "clay_stamp_round": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 4,
        "usage": "fixed",
        "recommended_for": ["AP counter", "round indicator", "small CTA"],
        "slice_insets": None,
    },
    "clay_tab_dark": {
        "source": "gpt2_clay_show_controls_atlas_v1.png",
        "order": 5,
        "usage": "9-slice",
        "recommended_for": ["name plate", "dark hint label"],
        "slice_insets": [54, 44, 54, 44],
    },
}


def green_background_mask(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.float32)
    green = rgb[:, :, 1].astype(np.float32)
    blue = rgb[:, :, 2].astype(np.float32)
    return (
        (green > 175)
        & (green > red * 1.42)
        & (green > blue * 1.32)
        & ((green - np.maximum(red, blue)) > 48)
    )


def foreground_components(rgb: np.ndarray) -> list[dict]:
    background = green_background_mask(rgb)
    mask = (~background).astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    count, _, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    components = []
    for index in range(1, count):
        x, y, width, height, area = map(int, stats[index])
        if area < 500:
            continue
        components.append(
            {
                "x": x,
                "y": y,
                "w": width,
                "h": height,
                "area": area,
                "touches_edge": x <= 2
                or y <= 2
                or x + width >= rgb.shape[1] - 2
                or y + height >= rgb.shape[0] - 2,
            }
        )
    return components


def rgba_with_keyed_green(rgb: np.ndarray) -> np.ndarray:
    data = rgb.astype(np.float32)
    red = data[:, :, 0]
    green = data[:, :, 1]
    blue = data[:, :, 2]
    maximum_other = np.maximum(red, blue)
    dominance = green - maximum_other
    ratio = maximum_other / np.maximum(green, 1)

    green_level = np.clip((green - 130) / 80, 0, 1)
    dominance_level = np.clip((dominance - 20) / 80, 0, 1)
    ratio_level = np.clip((0.82 - ratio) / 0.5, 0, 1)
    key_strength = np.minimum(np.minimum(green_level, dominance_level), ratio_level)
    alpha = np.clip(255 * (1 - key_strength), 0, 255).astype(np.uint8)
    alpha[alpha < 10] = 0

    rgba = np.dstack([rgb, alpha])
    fringe = (alpha > 0) & (alpha < 245) & (dominance > 18)
    rgba[:, :, 1][fringe] = np.minimum(
        rgba[:, :, 1][fringe],
        np.maximum(rgba[:, :, 0][fringe], rgba[:, :, 2][fringe]) + 10,
    )
    return rgba


def classify_paper(components: list[dict]) -> dict[str, dict]:
    if len(components) != 4:
        raise RuntimeError(f"Expected 4 paper components, got {len(components)}")
    widest = max(components, key=lambda component: component["w"])
    smallest = min(components, key=lambda component: component["area"])
    remaining = [component for component in components if component not in (widest, smallest)]
    portrait = max(remaining, key=lambda component: component["h"] / component["w"])
    popup = next(component for component in remaining if component is not portrait)
    return {
        "paper_stage_frame": widest,
        "paper_popup_frame": popup,
        "paper_ticket_card": portrait,
        "paper_tape_strip": smallest,
    }


def classify_controls(components: list[dict]) -> dict[str, dict]:
    if len(components) != 6:
        raise RuntimeError(f"Expected 6 control components, got {len(components)}")
    ordered = sorted(components, key=lambda component: (component["y"], component["x"]))
    names = [
        "clay_button_primary",
        "clay_status_magenta",
        "clay_button_secondary",
        "clay_status_teal",
        "clay_stamp_round",
        "clay_tab_dark",
    ]
    return dict(zip(names, ordered))


def crop_component(rgba: np.ndarray, component: dict, padding: int = 18) -> tuple[np.ndarray, list[int]]:
    height, width = rgba.shape[:2]
    x0 = max(0, component["x"] - padding)
    y0 = max(0, component["y"] - padding)
    x1 = min(width, component["x"] + component["w"] + padding)
    y1 = min(height, component["y"] + component["h"] + padding)
    return rgba[y0:y1, x0:x1], [x0, y0, x1 - x0, y1 - y0]


def make_contact_sheet(entries: list[dict]) -> Path:
    cell_width, cell_height = 420, 300
    sheet = Image.new("RGB", (cell_width * 2, cell_height * 5), (35, 38, 48))
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(entries):
        image = Image.open(entry["output"]).convert("RGBA")
        checker = Image.new("RGB", image.size, (235, 229, 213))
        checker_pixels = np.array(checker)
        tile = 18
        for y in range(0, image.height, tile):
            for x in range(0, image.width, tile):
                if (x // tile + y // tile) % 2:
                    checker_pixels[y : y + tile, x : x + tile] = (198, 205, 201)
        checker = Image.fromarray(checker_pixels)
        checker.paste(image, mask=image.getchannel("A"))
        checker.thumbnail((cell_width - 28, cell_height - 48), Image.Resampling.LANCZOS)
        column = index % 2
        row = index // 2
        x = column * cell_width + (cell_width - checker.width) // 2
        y = row * cell_height + 30 + (cell_height - 42 - checker.height) // 2
        sheet.paste(checker, (x, y))
        draw.text((column * cell_width + 12, row * cell_height + 8), entry["name"], fill=(255, 250, 235))

    path = AUDIT_DIR / "gpt2_clay_show_slices_contact_sheet.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    return path


def main() -> None:
    SLICE_DIR.mkdir(parents=True, exist_ok=True)
    entries = []

    source_components = {}
    for source_name in {
        info["source"] for info in ASSET_INFO.values()
    }:
        source_path = SOURCE_DIR / source_name
        rgb = np.array(Image.open(source_path).convert("RGB"))
        components = foreground_components(rgb)
        if source_name.startswith("gpt2_clay_show_paper"):
            assigned = classify_paper(components)
        else:
            assigned = classify_controls(components)
        source_components[source_name] = {
            "rgb": rgb,
            "rgba": rgba_with_keyed_green(rgb),
            "components": components,
            "assigned": assigned,
        }

    for name, info in ASSET_INFO.items():
        source = source_components[info["source"]]
        component = source["assigned"][name]
        crop, crop_box = crop_component(source["rgba"], component)
        output_path = SLICE_DIR / f"{name}.png"
        Image.fromarray(crop, "RGBA").save(output_path)
        visible_alpha = crop[:, :, 3]
        entries.append(
            {
                "name": name,
                "source": info["source"],
                "source_component": component,
                "crop_box": crop_box,
                "output": str(output_path),
                "size": [crop.shape[1], crop.shape[0]],
                "visible_pixel_ratio": round(float(np.mean(visible_alpha > 16)), 5),
                "semi_transparent_pixel_ratio": round(
                    float(np.mean((visible_alpha > 16) & (visible_alpha < 245))),
                    5,
                ),
                "usage": info["usage"],
                "recommended_for": info["recommended_for"],
                "slice_insets": info["slice_insets"],
            }
        )

    contact_sheet = make_contact_sheet(entries)
    report = {
        "assets": entries,
        "source_quality": {
            source_name: {
                "major_component_count": len(data["components"]),
                "components": data["components"],
            }
            for source_name, data in source_components.items()
        },
        "contact_sheet": str(contact_sheet),
    }
    report_path = SOURCE_DIR / "slices_manifest.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (AUDIT_DIR / "gpt2_clay_show_slices_manifest.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {len(entries)} slices and {contact_sheet}")


if __name__ == "__main__":
    main()
