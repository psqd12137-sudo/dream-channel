# 织梦频道 · channel dream

> **总述**：梦境探索 · 战棋走位 · 卡牌（放置 / 移动 / 连击）——一款邪典荒诞风格的 roguelike。多人协作仓库：**设计文档在 `docs/`，可玩竖切片在 `cabin-slice/`。**

远程：https://github.com/psqd12137-sudo/dream-channel

## 总 · 这是什么

- **产品名**：织梦频道（channel dream）
- **玩法方向**：梦境探索 · 战棋走位 · 卡牌（放置 / 移动 / 连击），**不做**山屋惊魂式力量拼点
- **参考系**：山屋惊魂的流程骨架 × 杀戮尖塔的构筑循环 × 以撒的「空间化战斗」——详见 [docs/design/玩法拓展概念与设计轴.md](./docs/design/玩法拓展概念与设计轴.md)
- **当前可玩**：`cabin-slice/` —— 浏览器竖切片（地图、战斗、存档、伪随机平面图等）
- **Windows 单机版**：`CabinSlice_织梦频道_Windows.zip`（双击即玩，见 [cabin-slice/README.md](./cabin-slice/README.md) 的「桌面版」小节）

成长主轴是否从「牌库构筑」改成「能力值」仍是**存疑议题**，见 [docs/open-questions.md](./docs/open-questions.md)。在拍板前，先别按新轴大改代码。

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
├── apps/                      ← 预留：多端 / 多切片工程
├── docs/                      ← 设计文档（策划 / 玩法概念 / 技术 / 环境接入）
│   ├── design/                ← 现行策划 + 玩法概念 + archive/ 历史稿
│   ├── tech/                  ← 技术方案与自测
│   └── setup/                 ← 环境接入 / 新机器拉取
├── cabin-slice/               ← 可玩切片（HTML / CSS / JS）
│   ├── data/                  ← JSON 内容 + 规则短稿（*.md）
│   └── desktop/               ← Windows exe 启动器源码
└── downloads/                 ← 本地下载 / 临时文件（不入库）
```

`apps/` 预留多端 / 多切片工程；当前可玩竖切片仍在 `cabin-slice/`。

## 分 · 文档索引（按职能分层）

### 总览与协作

| 文档 | 职能 |
| --- | --- |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | 分支 / PR / 文件分工 |
| [docs/open-questions.md](./docs/open-questions.md) | **存疑 / 未决设计**，改玩法前先看 |

### 设计（docs/design/）

| 文档 | 职能 |
| --- | --- |
| [docs/design/织梦频道_channel_dream_策划案与招标书.md](./docs/design/织梦频道_channel_dream_策划案与招标书.md) | 现行主策划 / 协作招标书 |
| [docs/design/玩法拓展概念与设计轴.md](./docs/design/玩法拓展概念与设计轴.md) | 玩法新意来源、设计轴、多人本质、三作参考系 |
| [docs/design/archive/](./docs/design/archive/) | 历史稿（早期策划案 / 旁支笔记） |

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

技术实现与自测见 [docs/tech/技术方案与自测.md](./docs/tech/技术方案与自测.md)；玩法细则见 [cabin-slice/README.md](./cabin-slice/README.md)。

### 路线

- 一局单机流程已打通；解谜事件、恢复曲线在持续迭代
- **存疑大项**：成长轴（能力值 vs 牌库）、视野与意图预警口径 —— 见 [docs/open-questions.md](./docs/open-questions.md)
- **愿景层（未开工）**：整图终局 Boss、多人分头 / 半场奸徒 / 联机 —— 见 [cabin-slice/data/multiplayer-haunt-sketch.md](./cabin-slice/data/multiplayer-haunt-sketch.md) 与 [玩法拓展概念与设计轴](./docs/design/玩法拓展概念与设计轴.md)

---

**总结**：先做透一集单机节目（可玩竖切片已通），再谈整图终局与多人。新玩法先对齐设计轴与存疑议题，避免方向打架。
