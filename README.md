# 织梦频道 · channel dream

> **总述**：梦境探索 · 战棋走位 · 卡牌（放置 / 移动 / 连击）——一款邪典荒诞风格的 roguelike。AI OC 作为节目演员与局外记忆层，不是独立产品。**唯一主策划在 `docs/design/织梦频道_channel_dream_策划案与招标书.md`；Web 基准在 `cabin-slice/`，Godot 3D 客户端在 `apps/godot/`。**

远程：https://github.com/psqd12137-sudo/dream-channel

## 总 · 这是什么

- **产品名**：织梦频道（channel dream）
- **玩法方向**：梦境探索 · 战棋走位 · 卡牌（放置 / 移动 / 连击），**不做**山屋惊魂式力量拼点
- **角色方向**：官方角色或玩家 OC 进入山屋；AI 根据真实战局生成本集回顾、后台日常与长期记忆，但不裁定玩法
- **参考系**：山屋惊魂的流程骨架 × 杀戮尖塔的构筑循环 × 以撒的「空间化战斗」——详见 [docs/design/玩法拓展概念与设计轴.md](./docs/design/玩法拓展概念与设计轴.md)
- **Web 规则基准**：`cabin-slice/` —— 浏览器/桌面竖切片（地图、战斗、存档、伪随机平面图等）
- **Godot 3D 客户端**：`apps/godot/` —— `Node3D + Camera3D + MeshInstance3D` 实现，含 3D 探索、摆房、战斗、事件小游戏与存档
- **AI OC 现状**：已并入唯一主策划，尚未实现；首期用 Lili 验证「事件日志 → 本集回顾 → 记忆碎片」
- **Windows 单机版**：`CabinSlice_织梦频道_Windows.zip`（双击即玩，见 [cabin-slice/README.md](./cabin-slice/README.md) 的「桌面版」小节）

成长主轴是否从「牌库构筑」改成「能力值」仍是**存疑议题**，见 [docs/open-questions.md](./docs/open-questions.md)。在拍板前，先别按新轴大改代码。

## 分 · 共用 Skill / 资产生成（概念仓）

角色黏土立绘、像素载具、序列帧绿幕跑循环等 **内容生产** 不在本仓维护 skill，统一走旁仓 **概念**（shared）。

| 项 | 说明 |
|----|------|
| **高权限入口（必读）** | `概念/AGENT_SKILL_ROUTER.md` |
| **工作区地图** | `概念/README.md`（`assets/` 资产 · `tools/` 工具） |
| **本机绝对路径例** | `C:\Users\Admin\Documents\概念\AGENT_SKILL_ROUTER.md` |
| **相对关系** | 与本仓并列：`Documents/概念` ↔ `Documents/channel_dream/dream-channel` |

**推荐 Cursor 多根工作区**：同时打开 `概念` + `dream-channel`（需要地编时再加 `jrpg`）。  
Agent 接到出图 / 跑帧 / 绿幕任务时：**先读 ROUTER**，再开对应 `概念/.cursor/skills/*/SKILL.md`。

| 要做 | 走 shared skill | 勿走 |
|------|-----------------|------|
| 黏土立绘 / STAND | `claymation-stopmo-craft` | vignette / 像素锁叠涂 |
| 跑循环 / 序列帧 / matte | `isometric-sprite-cycle-craft`（默认 dry-run） | 即梦未授权 Generate；AIDP edits 当 matte |
| 载具像素 remap | `retrofuturism-pixel-craft` | 角色跑帧 |
| Unity 上传 / 引擎配置 | — | **jrpg** 侧 skill（不是 channel 流程） |

即梦 / Gemini MCP 宿主在概念仓 `tools/jimeng-web-mcp`、`tools/gemini-web-mcp`；路径键见 `概念/paths.local.example.json`。

## 分 · 快速开始

```bash
git clone https://github.com/psqd12137-sudo/dream-channel.git
cd dream-channel/cabin-slice
python3 -m http.server 8787
```

浏览器打开 http://127.0.0.1:8787/，硬刷新（Ctrl+F5）。

详细：[docs/setup/另一台电脑一键拉取.md](./docs/setup/另一台电脑一键拉取.md) · 协作：[CONTRIBUTING.md](./CONTRIBUTING.md)

## 分 · 仓库结构

```text
dream-channel/
├── README.md                  ← 你在这里（仓库导航 + 文档索引）
├── CONTRIBUTING.md            ← 分支 / PR / 文件分工
├── CabinSlice_织梦频道_Windows.zip   ← Windows 单机版分发包
├── apps/
│   └── godot/                ← Godot 4 的 3D 客户端、测试与表现层资产
├── docs/                      ← 设计文档（策划 / 玩法概念 / 技术 / 环境接入）
│   ├── design/                ← 唯一主策划 + 玩法概念 + archive/ 历史稿
│   ├── tech/                  ← 技术方案与自测
│   └── setup/                 ← 环境接入 / 新机器拉取
├── cabin-slice/               ← 可玩切片（HTML / CSS / JS）
│   ├── data/                  ← JSON 内容 + 规则短稿（*.md）
│   └── desktop/               ← Windows exe 启动器源码
└── downloads/                 ← 本地下载 / 临时文件（不入库）
```

`cabin-slice/` 与 `apps/godot/` 是两条并行实现：前者作为最新版 Web 规则/内容基准，后者承接 3D 表现、交互和后续正式资产。Unity 工程不在本仓库内。

### 打开 Godot 版

Godot 4 可直接打开共享目录中的 `apps/godot/project.godot`：

```powershell
D:\godot\Godot_v4.7.1-stable_win64.exe --path "\\KC90G52G91.local\SharedFolder\new channel\apps\godot" --editor
```

网络共享上的首次资源导入和文件监听可能慢于本地磁盘；若遇到不稳定，可映射盘符或在本地 clone，项目的 `res://` 引用无需调整。

## 分 · 文档索引（按职能分层）

### 总览与协作

| 文档 | 职能 |
| --- | --- |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | 分支 / PR / 文件分工 |
| [docs/open-questions.md](./docs/open-questions.md) | **存疑 / 未决设计**，改玩法前先看 |

### 设计（docs/design/）

| 文档 | 职能 |
| --- | --- |
| [docs/design/织梦频道_channel_dream_策划案与招标书.md](./docs/design/织梦频道_channel_dream_策划案与招标书.md) | **唯一主策划** / 协作招标书；含 AI OC 整合口径 |
| [docs/design/玩法拓展概念与设计轴.md](./docs/design/玩法拓展概念与设计轴.md) | 玩法新意来源、设计轴、多人本质、三作参考系 |
| [docs/design/archive/](./docs/design/archive/) | 历史稿（无决策权；冲突时一律以唯一主策划为准） |

### 技术（docs/tech/）

| 文档 | 职能 |
| --- | --- |
| [docs/tech/技术方案与自测.md](./docs/tech/技术方案与自测.md) | 架构、关键系统、自测脚本 |

### 可玩切片（cabin-slice/）

| 文档 | 职能 |
| --- | --- |
| [cabin-slice/README.md](./cabin-slice/README.md) | 一局怎么玩、卡牌、Boss、桌面版打包 |
| [cabin-slice/data/run-scheme.md](./cabin-slice/data/run-scheme.md) | 战斗与成长细则 |
| [cabin-slice/data/cards-rules.md](./cabin-slice/data/cards-rules.md) | 出牌与奖励规则 |
| [cabin-slice/data/multiplayer-haunt-sketch.md](./cabin-slice/data/multiplayer-haunt-sketch.md) | 多人分头等设想短稿 |

### Godot 3D 客户端（apps/godot/）

| 文档 | 职能 |
| --- | --- |
| [apps/godot/README.md](./apps/godot/README.md) | 打开场景、操作、功能现状与回归测试 |
| [apps/godot/WEB_GODOT_PARITY.md](./apps/godot/WEB_GODOT_PARITY.md) | 最新 Web/EXE 与 Godot 功能对照 |
| [apps/godot/NEXT_PHASE_PLAN.md](./apps/godot/NEXT_PHASE_PLAN.md) | 近期完成度和表现层改进方案 |
| [apps/godot/PRESENTATION_PACK.md](./apps/godot/PRESENTATION_PACK.md) | 角色、动画、道具与场景资产一键导入约定 |

### 环境接入（docs/setup/）

| 文档 | 职能 |
| --- | --- |
| [docs/setup/另一台电脑一键拉取.md](./docs/setup/另一台电脑一键拉取.md) | 新机器克隆与启动 |
| [docs/setup/Cursor接入DeepSeek.md](./docs/setup/Cursor接入DeepSeek.md) | Cursor 接 DeepSeek 配置 |
| [docs/setup/Cursor接入火山方舟.md](./docs/setup/Cursor接入火山方舟.md) | Cursor 接火山方舟配置 |

## 总 · 切片现状与路线

### 现状（摘要）

| 模块 | 状态 |
| --- | --- |
| 大地图 / 房间 | 玩家摆房（`layoutRoll.mode=player`）；局内「重开」；祭坛/仪式不进随机图 |
| 战斗 | 走位 + 卡牌；意图红格；STS 风格结束层；战斗内可从「主页」回菜单（不计败绩） |
| 恢复 / 曲线 | 软化战斗曲线；战后/静室回血；低血慎战与撤退 |
| 音频 | 顶栏「音乐：开/关」 |
| 存档 | localStorage；含 `runSeed` / `roomLayout` |
| AI OC | 已完成产品合并与边界设计；代码未实现 |

技术实现与自测见 [docs/tech/技术方案与自测.md](./docs/tech/技术方案与自测.md)；玩法细则见 [cabin-slice/README.md](./cabin-slice/README.md)。

### 路线

- 一局单机流程已打通；解谜事件、恢复曲线在持续迭代
- 下一条产品验证链：Lili 事实日志 → 本集回顾 → 记忆碎片；AI 不可用时必须能模板降级
- **存疑大项**：成长轴（能力值 vs 牌库）、视野与意图预警口径 —— 见 [docs/open-questions.md](./docs/open-questions.md)
- **愿景层（未开工）**：整图终局 Boss、多人分头 / 半场奸徒 / 联机 —— 见 [cabin-slice/data/multiplayer-haunt-sketch.md](./cabin-slice/data/multiplayer-haunt-sketch.md) 与 [玩法拓展概念与设计轴](./docs/design/玩法拓展概念与设计轴.md)

---

**总结**：先做透一集单机节目，再让 Lili / 玩家 OC 真正记住这集；之后才扩自由 OC、整图终局与多人。项目只有一份主策划，旧 AI OC 文档仅供溯源。
