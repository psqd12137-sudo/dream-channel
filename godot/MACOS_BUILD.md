# macOS 本地版本

## 构建

使用 Godot 4.7.1 和同版本 export templates：

```powershell
Godot_v4.7.1-stable_win64.exe --headless --path godot --export-release "macOS Universal" "builds/macos/DreamChannel-macOS-universal.zip"
```

产物为同时支持 Apple Silicon (`arm64`) 与 Intel (`x86_64`) 的 Universal `.app` 压缩包。

Godot 4.7.1 官方模板生成的实际最低系统版本为：Apple Silicon macOS 13，Intel macOS 11。Retina 高分辨率已启用。

## 字体

游戏随包携带静态字重的 `Noto Sans CJK SC Regular`，UI 自绘文字、输入框和 3D 标签不依赖 macOS 系统字体，也不依赖平台对可变字体轴的解释。字体采用 SIL Open Font License 1.1，许可证见 `assets/fonts/OFL.txt`。

## 签名限制

Windows 构建机使用 Godot 内置的 ad-hoc 签名生成本地测试包。它不是 Apple 公证签名，因此下载后的应用仍可能被 Gatekeeper 隔离。如果 Finder 提示应用“已损坏”，请把 `.app` 拖入“应用程序”，再在终端执行：

```bash
xattr -dr com.apple.quarantine "/Applications/织梦频道 · Godot 3D.app"
open "/Applications/织梦频道 · Godot 3D.app"
```

公开分发前，必须在 macOS 构建机上配置 Apple Developer ID Application 证书，并完成 Hardened Runtime、签名与 Apple 公证。
