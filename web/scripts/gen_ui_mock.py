# -*- coding: utf-8 -*-
"""Generate UI mockups via ByteDance multimodal hub, with Unity refs."""
from __future__ import annotations

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(r"C:\Users\Admin\Documents\channel_dream")
OUT = ROOT / "dream-channel" / "cabin-slice" / "assets" / "ui" / "generated"
OUT.mkdir(parents=True, exist_ok=True)

# Prefer env AIDP_IMAGE_AK / AIDP_IMAGE_AK_FALLBACK — do not commit raw keys.
AKS = [ak for ak in (os.environ.get("AIDP_IMAGE_AK"), os.environ.get("AIDP_IMAGE_AK_FALLBACK")) if ak]


def api_url(ak: str) -> str:
    return f"https://aidp.bytedance.net/api/modelhub/online/multimodal/crawl?ak={ak}"


REFS = [
    ROOT / "dream-channel/cabin-slice/assets/ui/UI_HUD_Panel_ActionPanel_Normal.png",
    ROOT / "dream-channel/cabin-slice/assets/ui/SP_Character_HUD.png",
    ROOT / "dream-channel/cabin-slice/assets/ui/SP_LittleMap.png",
]

# Attach style refs as image_url. Flip False under heavy quota pressure.
USE_REFS = True


def b64_file(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def content_parts(prompt: str, refs: list[Path] | None = None) -> list[dict]:
    parts: list[dict] = [{"type": "text", "text": prompt}]
    if not refs:
        return parts
    for p in refs:
        if not p.exists():
            print("skip missing", p, file=sys.stderr)
            continue
        mime = "image/png" if p.suffix.lower() == ".png" else "image/jpeg"
        # Hub rejects request Part type inline_data; use data-URL image_url.
        parts.append(
            {
                "type": "image_url",
                "image_url": {"url": f"data:{mime};base64,{b64_file(p)}"},
            }
        )
    return parts


PROMPT_EXPLORE = """
你是游戏 UI 概念画师。根据附件 Unity/现有资产参考图，为《织梦频道 channel dream》网页竖切片画一张【探索盖屋界面】高保真 UI 概念图（不是照片，是游戏界面 mock）。

世界观：怀旧邪典荒诞儿童节目外壳——票根、嘴巴电视机、CRT 小地图、文件夹侧栏；颜色：teal #28b4a1、cream #fff4df、magenta #d12e7b、ink #2a221c、暖橙票根。

玩法目标（必须服务这些，不要纯装饰）：
1) 玩家一眼看到中央 CRT 地图上「我在哪」与可扩建「+」格
2) 扩建时在地图底部出现票根式候选房卡（不是奶油色居中弹窗）
3) 每张房卡显示：房间名、类型色边（惊吓红/静室绿/考验金）、门缺口朝向
4) 底部三个动作：摆下 / 旋转 / 取消——票根按钮，主操作「摆下」最醒目
5) 右侧文件夹侧栏（旁白/猜 Boss/宝贝箱）降噪，不要压过地图主任务
6) 行程进度「今天的行程 n/12」在地图头清晰可读

参考图用途：
- ActionPanel 橙黄票根：扩建候选卡与按钮材质
- Character HUD 锯齿票+彩色图标块：信息条气质
- LittleMap：CRT 电视机壳、天线、牙齿边

禁止：紫渐变赛博、通用深色玻璃弹窗、emoji、过密运营红点、把候选做成纯文字列表。

输出：单张横构图游戏 UI 完整屏 mock，16:9，清晰可读中文标签。
""".strip()

PROMPT_BATTLE = """
根据附件 Unity 票根/HUD 参考，为《织梦频道》画一张【战斗界面】高保真 UI mock（横屏）。

必须服务玩法：
1) 中央大棋盘格威胁清晰（必伤红实线 / 预告虚线 / 可走）
2) 右侧手牌栏固定宽度，牌可滚动；卡牌像票根/物品卡
3) 顶部行动力数字极大且醒目（玩家最常看）
4) 敌意图条短而清晰，不要长句占屏
5) 风格：cream 面板 + teal 描边电视机感 + 暖橙票根按钮；邪典儿童节目，不是暗黑魂

参考 ActionPanel 票根、Character HUD。禁止紫赛博、花哨多层阴影堆叠。
16:9 完整战斗屏，中文标签。
""".strip()


def call_gen(prompt: str, aspect: str, out_name: str, with_refs: bool | None = None) -> Path | None:
    use_refs = USE_REFS if with_refs is None else with_refs
    refs = REFS if use_refs else []
    body = {
        "stream": False,
        "model": "gemini-3-pro-image-preview",
        "max_tokens": 20000,
        "messages": [{"role": "user", "content": content_parts(prompt, refs)}],
        "response_modalities": ["TEXT", "IMAGE"],
        "image_config": {
            "aspectRatio": aspect,
            "imageSize": "1K",
            "imageOutputOptions": {"mimeType": "image/png"},
        },
    }
    raw = None
    last_err = None
    for attempt in range(5):
        for ak in AKS:
            req = urllib.request.Request(
                api_url(ak),
                data=json.dumps(body).encode("utf-8"),
                headers={
                    "Content-Type": "application/json",
                    "X-TT-LOGID": f"cabin-ui-{out_name}-{attempt}",
                },
                method="POST",
            )
            print(
                "requesting",
                out_name,
                "ak=..." + ak[-12:],
                "refs=",
                len(refs),
                "try",
                attempt + 1,
                flush=True,
            )
            try:
                with urllib.request.urlopen(req, timeout=180) as resp:
                    raw = resp.read().decode("utf-8", errors="replace")
                break
            except urllib.error.HTTPError as e:
                last_err = e
                err_body = e.read().decode("utf-8", errors="replace")[:900]
                print("HTTP", e.code, err_body, file=sys.stderr, flush=True)
                if e.code == 429:
                    time.sleep(12 + attempt * 15)
                    break  # next attempt
                if e.code in (401, 403):
                    continue
                if e.code == 400 and "permission" in err_body:
                    continue
                if e.code == 400 and "unsupport Part" in err_body:
                    raise
                raise
        if raw is not None:
            break
    if raw is None:
        raise last_err or RuntimeError("no response")
    data = json.loads(raw)
    (OUT / f"{out_name}.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2)[:200000], encoding="utf-8"
    )
    saved = None
    try:
        mm = data["choices"][0]["message"].get("multimodal_contents") or []
    except Exception:
        print(
            "bad response keys",
            list(data.keys()) if isinstance(data, dict) else type(data),
            file=sys.stderr,
        )
        print(raw[:1500], file=sys.stderr)
        return None
    idx = 0
    for block in mm:
        if block.get("type") != "inline_data":
            continue
        inline = block.get("inline_data") or {}
        b64 = inline.get("data")
        if not b64:
            continue
        ext = "png"
        mime = inline.get("mime_type") or "image/png"
        if "jpeg" in mime or "jpg" in mime:
            ext = "jpg"
        path = OUT / f"{out_name}_{idx}.{ext}"
        path.write_bytes(base64.b64decode(b64))
        print("saved", path, flush=True)
        saved = path
        idx += 1
    if not saved:
        for block in mm:
            if block.get("type") == "text":
                print("text:", (block.get("text") or "")[:400], flush=True)
        print("no image in response", file=sys.stderr)
    return saved


def main() -> None:
    if not AKS:
        raise SystemExit("Set AIDP_IMAGE_AK (and optional AIDP_IMAGE_AK_FALLBACK) before running.")
    # Prefer refs; on persistent 429 caller can set USE_REFS=False.
    call_gen(PROMPT_EXPLORE, "16:9", "explore_build_ui", with_refs=True)
    time.sleep(5)
    call_gen(PROMPT_BATTLE, "16:9", "battle_hud_ui", with_refs=True)


if __name__ == "__main__":
    main()
