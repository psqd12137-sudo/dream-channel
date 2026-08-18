# AI 播片动画资产库（ai_media）

本目录存放《织梦频道》的 **AI 生成播片动画（AI cutscene/cinematic）**。当前成员是主页循环背景动画——用主角形象生成的 AI 动画，是项目最有价值的资产之一。未来会持续加入更多 AI 播片动画，请按本规范归档。

## 当前资产

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `menu_video.mp4` | 3.81s 循环 · 1920×1080 · 30fps · 暗紫迷雾动画（主角形象 AI 生成） | Godot 主页背景循环动画（转码 OGV 后由 `VideoStreamPlayer` 播放）；`menu_video_preview.html` 提供浏览器预览 |
| `menu_video_preview.html` | 独立预览页（本地静态服务器打开） | 快速查看动画效果，无需启动游戏 |

## 归档规范（新增 AI 播片动画时遵守）

1. **命名**：`<场景或用途>_<日期或版本>.mp4`，小写下划线，例如 `menu_video.mp4`、`boss_entry_v1.mp4`。
2. **格式**：源文件统一 MP4（H.264，1920×1080 优先）；如需在 Godot 4 中播放，用 ffmpeg 转码一份 OGV 到 `godot/assets/ui/`：

   ```powershell
   ffmpeg -i input.mp4 -q:v 6 -q:a 6 -g:v 64 output.ogv
   ```

   （Godot 4 核心只支持 Ogg Theora；官方 FFmpeg 的 Theora 编码有已知伪影问题，务必用 `-g:v 64` 参数。）
3. **元数据**：在下方「资产清单」追加一行，记录内容、用途、分辨率/时长、来源。
4. **引用**：Godot 侧统一通过 `channel_3d.gd` 的 `_configure_home_video()` 加载；新增动画如需在游戏内使用，保持「源 MP4 在此、转码 OGV 在 godot/assets/ui」的分工。
5. **预览**：每个动画可配一个 `*_preview.html`，供本地静态服务器（`python -m http.server 8787`）直接打开核对。

## 资产清单

| 文件名 | 内容 | 用途 | 规格 | 来源 |
| --- | --- | --- | --- | --- |
| `menu_video.mp4` | 主页暗紫迷雾循环动画 | Godot 主页背景 + 浏览器预览 | 1920×1080 · 3.81s · 30fps | 主角形象 AI 生成 |

> Godot 侧转码副本：`godot/assets/ui/menu_video.ogv`（约 0.2MB，`-q:v 6 -q:a 6 -g:v 64` 转码）。
