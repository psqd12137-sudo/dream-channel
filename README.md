# 织梦频道 · channel dream

《织梦频道》是一款以梦境探索、空间走位和卡牌放置为核心的邪典儿童玩具秀 roguelike。玩家进入的是一档会失控的节目；可构建房屋以纸盒、黏土和毛毡微缩布景呈现，不是写实住宅或传统恐怖山屋。Godot 4 客户端是当前唯一正式开发主线；Web 版只用于低成本验证玩法假设。Unity 工程不属于本仓库。

## 从这里开始

| 想了解什么 | 阅读或打开 |
| --- | --- |
| 产品定位与已拍板设计 | [现行主策划](./docs/design/织梦频道_channel_dream_策划案与招标书.md) |
| 尚未拍板的问题 | [未决设计](./docs/open-questions.md) |
| 全部正式文档及冲突处理 | [文档地图](./docs/README.md) |
| 运行 Web 版 | [Web README](./web/README.md) |
| 打开 Godot 版 | [Godot README](./godot/README.md) |
| 修改和提交代码 | [协作指南](./CONTRIBUTING.md) |

## 开发主线与验证原型

| 路径 | 定位 | 冲突时如何处理 |
| --- | --- | --- |
| `godot/` | 正式 Godot 4 客户端 | 玩法、数据、交互、表现和回归测试均以这里的实现为准 |
| `web/` | Web 玩法验证原型及旧桌面封装 | 只验证尚未拍板的玩法，不承担正式 UI、内容同步或发布质量 |

若策划已经拍板，以现行主策划为准；若策划未写清，以 Godot 中有测试覆盖的行为作为当前客户端事实。Web 的实验结果只有在明确采纳并迁入 Godot 后才成为正式实现，不再要求两端 UI 或代码逐项同步。

## 工作目录

当前团队共享工作区为：

```text
\\192.168.1.21\bytedance\Shared\new channel
```

（本机也可通过 Z: 映射访问。仓库以 git 为准：两台开发机各自 clone，绝对路径不同，因此文档一律使用仓库相对路径；Godot 开发在各自本机进行。）

- Web 修改在 `web/` 进行。
- Godot 修改在 `godot/` 进行。
- 策划与跨客户端文档在 `docs/` 进行。
- `.godot/`、日志、截图、下载和本机 MCP 配置不提交。

共享路径是团队约定，不是代码依赖。重新 clone 到其他目录后，项目内相对链接与 Godot 的 `res://` 引用仍应正常工作。

## 快速运行

### Web

```powershell
Set-Location "<repo>\web"   # <repo> = 本机 clone 出的仓库根
python -m http.server 8787
```

浏览器打开 `http://127.0.0.1:8787/`。桌面包与完整操作见 [Web README](./web/README.md)。注意：**Web 版以共享盘 `\\192.168.1.21\bytedance\Shared\new channel\web` 下 `CabinSlice_织梦频道.exe` 的实际行为为准**，本仓库 `web/` 已与该基准同步。

### Godot

技术要求：**Godot 4.7.x**（4.6 及更早版本不受支持）。打开 [godot/project.godot](./godot/project.godot)，或运行：

```powershell
<godot> --path "<repo>\godot" --editor
# <godot> = 本机 Godot 4.7.1 可执行文件；<repo> = 本机 clone 出的仓库根
```

- 主场景是 `godot/channel_3d.tscn`（`run/main_scene` 已指向它），编辑器里按 **F5** 运行；`godot/main.tscn` 是旧版 2D 原型，仅供历史对照，不要在其上开发。
- **不要**运行仓库外层目录里的 `DreamChannel.exe`——那是 2025 年的 Unity 旧构建，与本仓库无关。
- Godot 开发以各自本机仓库为准，不再依赖网络共享；首次资源导入后由 `.godot/` 缓存加速。详细技术要求与自检见 [Godot README](./godot/README.md)。

## 仓库结构

```text
dream-channel/
├── README.md                  # 仓库入口
├── CONTRIBUTING.md            # 修改、验证与提交约定
├── docs/
│   ├── README.md              # 文档地图与权威等级
│   ├── design/                # 现行设计、设计分析与历史归档
│   ├── tech/                  # 跨项目或客户端技术说明
│   └── setup/                 # 环境接入说明
├── godot/                     # Godot 4 正式客户端（本地权威主线）
└── web/                       # Web 规则原型与桌面封装
    ├── ai_media/              # AI 播片动画资产库（源 MP4 + 规范）
    ├── releases/              # 桌面发布版与自测日志归档
    └── ...
```

根目录的压缩包、图片、资料库和实验目录不是正式文档入口。判断产品状态时只使用 [文档地图](./docs/README.md) 收录的文件。

## 当前方向

先在 Godot 中完成一集邪典儿童玩具秀的探索、搭建、战斗、事件、成长、结局和表现闭环，再扩展 AI 演员记忆、整图终局与多人玩法。房屋 PCG 既要保证拓扑和战斗可读性，也要像可被看见制作痕迹的实体节目布景。正式完成度以 Godot README、执行计划和回归测试为准；Web 实验状态不计入产品完成度。

## 任务看板

> 工作流约定：**每次推送前确认并同步更新本看板**。已完成项归入对应文档（`godot/README.md`、`docs/status-*.md`），进行中/待办保持最新。

### 已完成（2026-08-21）

- [x] 莉莉黏土角色 FBX 接入（41 骨骼、完整动作集、坐/工作互动映射）
- [x] 镜头系统：开局由远至进入场运镜、玩家移动延迟跟随（只平移不旋转）、画幅偏下构图、拖动松手延迟回位
- [x] 战斗镜头自始至终对准玩家-怪物中点偏上，跟随速率与探索一致（3.4）
- [x] 战斗 UI 杀戮尖塔式：棋盘全幅无框无蒙层、手牌底部露出悬停升起、敌人意图 3D 头顶 Label3D
- [x] 修复 UI 点击对应错误（phase 切换 world rect 不同步根因）+ 大地图镜头跳变（跟随期间被重置）
- [x] 相机共享逻辑拆分 `camera_follow_math.gd`；新增 `camera_dolly_follow_regression`、`ui_hit_regression`，全套 headless 回归通过

### 进行中

- [ ] 战斗 UI 视觉打磨（提示词 `docs/battle_ui_polish_prompt.md` 交 Codex 执行，不改行为）

### 待办

- [ ] 玩家验收镜头手感参数（跟随速率 3.4 / 回位延迟 1.5s / 偏下偏移 0.15·0.12）
- [ ] 确认 `apps/`、`cabin-slice/`、`godot-mcp-pro-v1.16.0/` 三个未跟踪目录：入库还是清理
- [ ] `gh auth refresh` 轮换一次 gh OAuth token（早期调试曾打印进会话日志）

## 近期改动（2026-08-19 推送）

本批改动包含以下内容（均为 Godot 主线 + 文档整理，Web 规则未变）：

| 项 | 说明 |
| --- | --- |
| **主页 UI 复刻** | Godot 主页改为深紫电视节目风：循环播放主角 AI 播片动画（`ai_media/menu_video`），主/次按钮使用 Unity 版按钮贴图（洋红/青胶囊），保留「回到标题」与「节目测试台」。 |
| **PCG 建造转正** | `kenney_build_lab_mode` 由实验开关转为默认开启，正式主游玩（开局/读档）全程使用 Kaykit/Kenney 桌模渲染房间（门洞/墙/透视/悬浮示意）。 |
| **渲染器修复** | 项目渲染器从 `gl_compatibility`（OpenGL，与 NVIDIA 驱动冲突导致编辑器崩溃）改为默认 `forward_plus`（Vulkan）。 |
| **MCP 工具装配** | 恢复 Godot MCP Pro（`addons/godot_mcp`，本地忽略不入库）；server 位于 `G:\dream-channel\.tools\godot-mcp-pro\server`，配置见 `godot/.mcp.json`。 |
| **Web 目录整理** | web 拆为 `ai_media/`（AI 播片动画）+ `releases/`（exe 与 lab 日志）+ 活跃源码，详见 [Web README](./web/README.md)。 |
| **标准明确** | Web 规则基准 = 共享盘 `CabinSlice_织梦频道.exe` 实际行为；Godot 为 3D 表现分支，本地权威开发主线。 |
