# -*- coding: utf-8 -*-
"""Best-effort: open Cursor Models settings and put Ark values on clipboard in order.

Cursor stores API keys in OS secure storage — cannot write them from a script.
This helper focuses Cursor, opens Settings, and stages paste values for you.
"""
from __future__ import annotations

import ctypes
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / ".env"

user32 = ctypes.windll.user32


def load_env() -> dict[str, str]:
    out: dict[str, str] = {}
    if not ENV.is_file():
        return out
    for line in ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def set_clipboard(text: str) -> None:
    # Prefer clip.exe for reliability on Windows
    p = subprocess.run(["clip"], input=text.encode("utf-16le"), check=False)
    if p.returncode != 0:
        raise SystemExit("Failed to set clipboard")


def find_cursor_hwnd() -> int:
    targets: list[int] = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def enum_proc(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length <= 0:
            return True
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buf, length + 1)
        title = buf.value or ""
        # Prefer main editor window titles
        if "Cursor" in title and "Agents" not in title:
            targets.append(hwnd)
        elif title == "Cursor Agents":
            targets.append(hwnd)
        return True

    user32.EnumWindows(enum_proc, 0)
    return targets[0] if targets else 0


def activate(hwnd: int) -> None:
    SW_RESTORE = 9
    user32.ShowWindow(hwnd, SW_RESTORE)
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.4)


def send_hotkey(mod_vk: int, key_vk: int) -> None:
    KEYEVENTF_KEYUP = 0x0002
    user32.keybd_event(mod_vk, 0, 0, 0)
    user32.keybd_event(key_vk, 0, 0, 0)
    user32.keybd_event(key_vk, 0, KEYEVENTF_KEYUP, 0)
    user32.keybd_event(mod_vk, 0, KEYEVENTF_KEYUP, 0)


def main() -> None:
    env = load_env()
    key = env.get("ARK_API_KEY", "").strip()
    base = (env.get("ARK_BASE_URL") or "https://ark.cn-beijing.volces.com/api/v3").strip()
    if not key:
        raise SystemExit(f"Missing ARK_API_KEY in {ENV}")

    hwnd = find_cursor_hwnd()
    if not hwnd:
        raise SystemExit("找不到 Cursor 窗口，请先打开 Cursor。")

    activate(hwnd)
    # Ctrl+Shift+J → Cursor Settings (common shortcut)
    VK_CONTROL, VK_SHIFT, VK_J = 0x11, 0x10, 0x4A
    send_hotkey(VK_CONTROL, 0)  # noop safety
    user32.keybd_event(VK_CONTROL, 0, 0, 0)
    user32.keybd_event(VK_SHIFT, 0, 0, 0)
    user32.keybd_event(VK_J, 0, 0, 0)
    user32.keybd_event(VK_J, 0, 0x0002, 0)
    user32.keybd_event(VK_SHIFT, 0, 0x0002, 0)
    user32.keybd_event(VK_CONTROL, 0, 0x0002, 0)
    time.sleep(0.8)

    # Stage key first for paste into OpenAI API Key
    set_clipboard(key)
    print("已打开 Cursor Settings（若未弹出请按 Ctrl+Shift+J）。")
    print()
    print("请按下面顺序操作（剪贴板已放好 Key，直接 Ctrl+V）：")
    print("1) 左侧点 Models")
    print("2) OpenAI API Key 框：Ctrl+V → 点 Save")
    print("3) 勾选 Override OpenAI Base URL")
    print("4) 回车后我会把 Base URL 放进剪贴板…")
    input("填完 Key 并 Save 后，按 Enter 继续把 Base URL 放到剪贴板… ")
    set_clipboard(base)
    print(f"剪贴板已换成 Base URL:\n{base}")
    print("粘贴到 Override 框后，用 Add Custom Model 添加：")
    print("  deepseek-v4-flash-260425")
    print("  deepseek-v4-pro-260425")
    models = "deepseek-v4-flash-260425"
    input("需要的话再按 Enter，把 flash 模型名放到剪贴板… ")
    set_clipboard(models)
    print("已复制 deepseek-v4-flash-260425。下一个模型名：")
    input("Enter → 复制 pro 模型名… ")
    set_clipboard("deepseek-v4-pro-260425")
    print("已复制 deepseek-v4-pro-260425。完成后在聊天里选模型发「你好」测通。")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(1)
