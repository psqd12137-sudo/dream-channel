#!/usr/bin/env bash
# 打包 Windows exe：把 cabin-slice 游戏内容复制进 launcher/web 并交叉编译。
# 需要 Go 工具链（macOS 上可直接产出 Windows exe）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"   # cabin-slice
LAUNCHER="$ROOT/desktop/launcher"
WEB="$LAUNCHER/web"
GO_BIN="${GO_BIN:-go}"

echo "==> 同步游戏资源到 web/ ..."
rm -rf "$WEB"
mkdir -p "$WEB"
# 只打包运行时需要的目录/文件，排除开发产物
for item in index.html css js data assets; do
  cp -R "$ROOT/$item" "$WEB/"
done

echo "==> 构建 darwin 测试版 ..."
cd "$LAUNCHER"
"$GO_BIN" build -trimpath -ldflags "-s -w" -o "$LAUNCHER/cabin-slice-darwin" .
echo "    输出: $LAUNCHER/cabin-slice-darwin"

echo "==> 交叉编译 Windows x64 exe ..."
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 "$GO_BIN" build -trimpath -ldflags "-s -w" -o "$ROOT/CabinSlice_织梦频道.exe" .
echo "    输出: $ROOT/CabinSlice_织梦频道.exe"

echo "==> 完成"
