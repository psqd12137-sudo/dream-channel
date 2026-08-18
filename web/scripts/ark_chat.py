# -*- coding: utf-8 -*-
"""Minimal Volcengine Ark chat helper. Loads Key from repo .env / env vars."""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # dream-channel/


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key, val = key.strip(), val.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = val


def chat(prompt: str, *, model: str | None = None, system: str = "你是人工智能助手.") -> str:
    load_dotenv(ROOT / ".env")
    api_key = os.environ.get("ARK_API_KEY", "").strip()
    if not api_key:
        raise SystemExit("Missing ARK_API_KEY. Put it in dream-channel/.env or export it.")
    base = (os.environ.get("ARK_BASE_URL") or "https://ark.cn-beijing.volces.com/api/v3").rstrip("/")
    model = model or os.environ.get("ARK_MODEL_FLASH") or "deepseek-v4-flash-260425"
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ],
    }
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"]


def main() -> None:
    parser = argparse.ArgumentParser(description="Ark chat smoke test")
    parser.add_argument("prompt", nargs="?", default="你好")
    parser.add_argument(
        "--model",
        choices=("flash", "pro"),
        default="flash",
        help="flash=deepseek-v4-flash · pro=deepseek-v4-pro",
    )
    args = parser.parse_args()
    load_dotenv(ROOT / ".env")
    model = (
        os.environ.get("ARK_MODEL_PRO")
        if args.model == "pro"
        else os.environ.get("ARK_MODEL_FLASH")
    )
    try:
        print(chat(args.prompt, model=model))
    except urllib.error.HTTPError as e:
        print(e.read().decode("utf-8", errors="replace")[:2000], file=sys.stderr)
        raise SystemExit(e.code)


if __name__ == "__main__":
    main()
