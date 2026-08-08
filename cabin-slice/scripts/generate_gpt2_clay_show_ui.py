#!/usr/bin/env python3
"""Generate two clay-cartoon UI asset atlases through AIDP GPT Image 2."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import re
import time
import uuid
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


REPO = Path(__file__).resolve().parents[2]
CONCEPT_ROOT = Path(os.environ.get("CONCEPT_ROOT", r"C:\Users\Admin\Documents\概念"))
STYLE_DIR = CONCEPT_ROOT / "assets" / "design_refs" / "style_direction"
OUT_DIR = REPO / "cabin-slice" / "assets" / "ui" / "generated" / "gpt2_clay_show_v1"
AUDIT_DIR = REPO / "downloads" / "clay-cartoon-ui-audit"
ENDPOINT = "https://aidp.bytedance.net/gpt/openapi/online/v2/crawl/openai/images/edits"


ATLAS_SPECS = {
    "gpt2_clay_show_paper_atlas_v1": {
        "prompt": """
Create a production-ready game UI asset atlas, not a full screen mockup.

Image 1 is the required blank chroma-key layout canvas. Images 2 and 3 are the
approved handmade cardboard miniature and clay material style references.
Image 4 is the current game UI only for functional context. Do not reproduce
the screenshot and do not include characters or scenery.

Final canvas must stay 1024 by 1024 with a perfectly flat solid #00FF00
background. Arrange exactly FOUR isolated objects with at least 70 pixels of
pure green separation. No object may touch another object or the canvas edge.

TOP, centered, largest object:
- a wide 16:9 hand-cut corrugated-cardboard television stage outer frame;
- visible layered corrugation, rough cream paper face, teal painted edge,
  tiny magenta and warm-orange paper accents;
- a completely open #00FF00 center suitable for DOM content;
- irregular handmade edges but a clear rectangular nine-slice-safe border.

BOTTOM LEFT:
- a 4:3 rough stacked-cardboard popup frame with a fully open #00FF00 center;
- thick paper depth, torn fibers, subtle clay fingerprints on corner fasteners;
- no decorations intruding into the central text-safe area.

BOTTOM CENTER:
- a portrait 3:4 cream ticket/card base with punched side holes and scalloped
  paper edges; clean empty center for DOM text; no icon or writing.

BOTTOM RIGHT:
- one short torn masking-tape strip with fibrous edges, warm cream paper,
  blank and unmarked.

Style: creepy-cute cult children's stop-motion TV program, handmade cardboard
diorama, tactile paper fibers, matte clay details, practical studio light,
teal/cream/magenta/ink/warm-orange palette. Not preschool candy art.

Hard constraints: no text, no pseudo-text, no letters, no numbers, no runes,
no meaningful symbols, no logo, no characters, no full-screen interface,
no black web panels, no glassmorphism, no cyberpunk, no neon green outlines,
no glossy vinyl, no shadows extending outside each object's isolated boundary.
""".strip(),
        "references": [
            STYLE_DIR / "approved_lili_cardboard_diorama_lock.png",
            STYLE_DIR / "clay_material_atmosphere_lock.png",
            REPO / "downloads" / "full-flow-audit" / "after_03_explore_build_native_100.png",
        ],
    },
    "gpt2_clay_show_controls_atlas_v1": {
        "prompt": """
Create a production-ready game UI asset atlas, not a full screen mockup.

Image 1 is the required blank chroma-key layout canvas. Images 2 and 3 are the
approved handmade cardboard miniature and clay material style references.
Image 4 is the current battle UI only for functional context. Do not reproduce
the screenshot and do not include characters, rooms, cards, or scenery.

Final canvas must stay 1024 by 1024 with a perfectly flat solid #00FF00
background. Arrange exactly SIX isolated tactile UI objects in a clean 3 by 2
layout. Keep at least 70 pixels of pure green between objects and at least
45 pixels to the canvas edge. No shadows may cross into another object's area.

Objects:
1. A wide 3:1 warm-orange clay push-button base, thick pressed edge and subtle
   fingerprints, blank center for DOM text.
2. A wide 3:1 teal clay secondary-button base, same physical family, blank.
3. A compact 2:1 cream-and-magenta clay status plate for AP or health numbers,
   blank readable center.
4. A compact 2:1 teal-and-cream clay status plate, blank readable center.
5. A small round warm-orange clay stamp/seal base with no emblem or symbol.
6. A small irregular ink-dark clay riveted tab base with cream paper inset,
   no icon and no text.

Style: creepy-cute cult children's stop-motion TV program, hand-sculpted matte
clay, slight fingerprints and tool marks, cardboard miniature prop language,
practical soft spotlight, teal/cream/magenta/ink/warm-orange palette. The forms
must feel like physical props a puppet can press, not flat website buttons.

Hard constraints: no text, no pseudo-text, no letters, no numbers, no runes,
no meaningful symbols, no logo, no characters, no full-screen interface,
no metallic sci-fi panel, no glassmorphism, no cyberpunk, no neon outlines,
no glossy vinyl, no black rectangular web container, no overlapping objects.
""".strip(),
        "references": [
            STYLE_DIR / "approved_lili_cardboard_diorama_lock.png",
            STYLE_DIR / "clay_material_atmosphere_lock.png",
            REPO / "downloads" / "full-flow-audit" / "after_05_boss_native_100.png",
        ],
    },
}


def load_api_key() -> str:
    for name in ("GPT_IMAGE_AK", "AIDP_IMAGE_AK"):
        value = os.environ.get(name, "").strip()
        if value:
            return value

    secrets = CONCEPT_ROOT / "secrets.local.md"
    if secrets.exists():
        match = re.search(r"apiKey\s*=\s*([A-Za-z0-9_-]{16,})", secrets.read_text(encoding="utf-8"))
        if match:
            return match.group(1)

    raise RuntimeError("GPT Image API key is unavailable in env or concept secrets.local.md")


def create_green_template() -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / "_atlas_green_template_1024.png"
    Image.new("RGB", (1024, 1024), (0, 255, 0)).save(path)
    return path


def append_text_part(body: bytearray, boundary: str, name: str, value: str) -> None:
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
    body.extend(value.encode("utf-8"))
    body.extend(b"\r\n")


def append_file_part(body: bytearray, boundary: str, path: Path, index: int) -> None:
    mime = "image/jpeg" if path.suffix.lower() in {".jpg", ".jpeg"} else "image/png"
    suffix = ".jpg" if mime == "image/jpeg" else ".png"
    filename = "photoshop-input.png" if index == 1 else f"photoshop-reference-{index}{suffix}"
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        (
            f'Content-Disposition: form-data; name="image[]"; filename="{filename}"\r\n'
            f"Content-Type: {mime}\r\n\r\n"
        ).encode()
    )
    body.extend(path.read_bytes())
    body.extend(b"\r\n")


def call_gpt_image(api_key: str, stem: str, prompt: str, image_paths: list[Path]) -> dict:
    missing = [str(path) for path in image_paths if not path.exists()]
    if missing:
        raise FileNotFoundError(f"Missing reference images: {missing}")

    boundary = "----DreamChannelGptImage" + uuid.uuid4().hex
    body = bytearray()
    for index, path in enumerate(image_paths, start=1):
        append_file_part(body, boundary, path, index)
    for name, value in (
        ("prompt", prompt),
        ("model", "gpt-image-2"),
        ("quality", "medium"),
        ("n", "1"),
        ("size", "1024x1024"),
    ):
        append_text_part(body, boundary, name, value)
    body.extend(f"--{boundary}--\r\n".encode())

    log_id = "channel-ui-gpt2-" + uuid.uuid4().hex[:12]
    request = urllib.request.Request(
        f"{ENDPOINT}?ak={api_key}",
        data=bytes(body),
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "X-TT-LOGID": log_id,
        },
        method="POST",
    )

    last_error: Exception | None = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=360) as response:
                payload = json.loads(response.read().decode("utf-8", errors="replace"))
            encoded = payload["data"][0]["b64_json"]
            image_bytes = base64.b64decode(encoded)
            output_path = OUT_DIR / f"{stem}.png"
            output_path.write_bytes(image_bytes)
            with Image.open(output_path) as image:
                size = list(image.size)
            return {
                "stem": stem,
                "output": str(output_path),
                "size": size,
                "bytes": len(image_bytes),
                "sha256": hashlib.sha256(image_bytes).hexdigest(),
                "log_id": log_id,
                "attempt": attempt + 1,
                "references": [str(path) for path in image_paths],
                "prompt": prompt,
            }
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:600]
            last_error = RuntimeError(f"HTTP {exc.code}: {detail}")
            if exc.code == 429 or "-4302" in detail:
                time.sleep(12 + attempt * 8)
                continue
            raise last_error
        except (KeyError, ValueError, json.JSONDecodeError) as exc:
            raise RuntimeError("GPT Image response did not contain data[0].b64_json") from exc

    raise last_error or RuntimeError("GPT Image request failed")


def main() -> None:
    api_key = load_api_key()
    green_template = create_green_template()
    results = []

    for index, (stem, spec) in enumerate(ATLAS_SPECS.items()):
        image_paths = [green_template, *spec["references"]]
        print(f"Generating {stem} ({index + 1}/{len(ATLAS_SPECS)})", flush=True)
        results.append(call_gpt_image(api_key, stem, spec["prompt"], image_paths))
        if index + 1 < len(ATLAS_SPECS):
            time.sleep(4)

    manifest = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": "gpt-image-2",
        "quality": "medium",
        "size": "1024x1024",
        "results": results,
    }
    manifest_path = OUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    (AUDIT_DIR / "gpt2_generation_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {manifest_path}", flush=True)


if __name__ == "__main__":
    main()
