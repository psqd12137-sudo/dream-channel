#!/bin/bash
# 织梦频道：双击本文件即可启动网页游戏（macOS）
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="${CABIN_PORT:-8787}"

if ! command -v python3 >/dev/null 2>&1; then
  osascript -e 'display dialog "未找到 Python 3。请先安装 Python 3，再重新启动游戏。" buttons {"好"} with icon stop' >/dev/null 2>&1 || true
  exit 1
fi

cd "$ROOT" || exit 1
# 如果默认端口已被旧进程占用，自动顺延到下一个可用端口，避免浏览器打开到错误的服务。
if [ -z "${CABIN_PORT:-}" ]; then
  PORT="$(python3 - <<'PY'
import socket
for port in range(8787, 8837):
    with socket.socket() as s:
        try:
            s.bind(('127.0.0.1', port))
            print(port)
            break
        except OSError:
            pass
PY
)"
fi
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT" >/tmp/cabin-slice-http.log 2>&1 &
SERVER_PID=$!
cleanup() { kill "$SERVER_PID" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

sleep 0.4
URL="http://127.0.0.1:${PORT}/"
if ! curl -fsS "$URL" >/dev/null 2>&1; then
  printf '启动失败，请查看 /tmp/cabin-slice-http.log\n'
  exit 1
fi
open "$URL"
printf '\n织梦频道已启动：%s\n关闭此窗口即可停止服务。\n' "$URL"
wait "$SERVER_PID"
