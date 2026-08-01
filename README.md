# 织梦频道 · channel dream

多人协作仓库：**设计文档在 `docs/`，可玩竖切片在 `cabin-slice/`。**

远程：https://github.com/psqd12137-sudo/dream-channel  

## 这是什么

- **产品名**：织梦频道（channel dream）  
- **玩法方向**：梦境探索 · 战棋走位 · 卡牌（放置 / 移动 / 连击），**不做**山屋惊魂式力量拼点  
- **当前可玩**：`cabin-slice/` —— 浏览器竖切片（地图、战斗、存档、伪随机平面图等）

成长主轴是否从「牌库构筑」改成「能力值」仍在 **存疑**，见 [docs/open-questions.md](./docs/open-questions.md)。先别按新轴大改代码。

## 仓库结构

```text
dream-channel/
├── README.md                 ← 你在这里
├── CONTRIBUTING.md           ← 分支 / PR / 改哪份文件
├── docs/
│   ├── README.md             ← 文档索引
│   ├── open-questions.md     ← 存疑议题
│   ├── setup/                ← 新机器拉取
│   └── design/               ← 现行策划 + archive/
└── cabin-slice/              ← 可玩切片（HTML / CSS / JS）
    ├── index.html
    ├── data/                 ← JSON + 切片规则短稿
    ├── js/ css/ assets/
    └── scripts/              ← 自测脚本
```

> 原计划把切片迁到 `apps/cabin-slice/`，本机有进程锁目录暂未完成；协作路径以 **`cabin-slice/`** 为准。迁完会改 README。

## 快速开始

```bash
git clone https://github.com/psqd12137-sudo/dream-channel.git
cd dream-channel/cabin-slice
python3 -m http.server 8787
```

浏览器打开 http://127.0.0.1:8787/ ，硬刷新（Ctrl+F5）。

详细： [docs/setup/另一台电脑一键拉取.md](./docs/setup/另一台电脑一键拉取.md) · 协作： [CONTRIBUTING.md](./CONTRIBUTING.md)

## 切片现状（摘要）

| 模块 | 状态 |
| --- | --- |
| 大地图 / 房间 | 种子伪随机连通平面图；局内「重开」；祭坛/仪式不进随机图 |
| 战斗 | 走位 + 卡牌；意图红格；STS 风格结束层；战斗内「主页」回菜单（不记败） |
| 恢复 / 曲线 | 软化战斗曲线；战后/静室回血；低血慎战与撤退 |
| 音频 | 顶栏「音乐：开/关」 |
| 存档 | localStorage；含 `runSeed` / `roomLayout` |

细则： [cabin-slice/README.md](./cabin-slice/README.md)、[data/run-scheme.md](./cabin-slice/data/run-scheme.md)、[data/cards-rules.md](./cabin-slice/data/cards-rules.md)

## 技术方案（当前）

**纯前端原型**：HTML/CSS/JS + JSON 数据驱动，无框架、无构建步骤，`python3 -m http.server` 即可跑。正式单机样片预计 Godot 4.x，数据保持 JSON/Resource 驱动以利规则迁移。

### 架构

| 文件 | 职责 |
| --- | --- |
| `index.html` | 单页多屏（标题 / 探索 / 战斗 / 沙盒），挂 CSS + 5 个 JS 模块 |
| `js/game.js` | 核心（约 8.5k 行）：状态机、探索、战斗、Boss、存档、遥测 |
| `js/audio.js` | Web Audio 程序化音效（振荡器 + 滤波合成，无音频文件） |
| `js/sideview.js` | 2D WASD 横版手感沙盒（临时占位，3D 微缩前） |
| `js/qte.js` | 打字追逐 QTE（警察抓小偷，整句容错） |
| `js/puzzle.js` | 八数码滑块拼图（保证可解滑乱 + 每局 3 次刷新） |
| `data/*.json` | 内容数据：rooms / cards / relics / bosses / pressure / tutorial |

### 关键系统

| 系统 | 实现 |
| --- | --- |
| 伪随机平面图 | mulberry32 种子 PRNG（`makeRng(seed)`）；`runSeed` 落盘可复现；拓扑：树 / 网 / 混合 / 脊 / 翼 |
| 摆房盖屋 | `layoutRoll.mode=player`：抽房 → 旋转门形 → 双边开门连通 |
| 行程配比 | `visitMix` ≈ 惊吓 40% / 静室 35% / 事件 25%，按种子分配 `runRole` |
| 战斗寻路 | 网格 + 墙挡视线（LoS）；敌人绕墙追击 / 巡逻 / `lastSeen` 搜索 |
| 意图预告 | 每回合模拟敌行动力预算 → 红格 = 会受伤；蓝虚线 = 它下一步 |
| 空间连击 | 盐道 / 闪瞎 / 夹击 / 纸影 / 追击踩踏 / 高台砸击 / 隧道 |
| Boss 仪式 | 双轨：熄锚 or 打血；播出进度满失败；蓄力砸地可灭锚 |
| 存档 | `localStorage` `cabin-run-v3`：进度 + `runSeed` + `roomLayout`；旧档兼容补门形 / 行程 |
| 实验遥测 | `cabin-lab-v1`：胜负 / 回合 / 输出 / 受伤 / 破韧 / 连击 / 牌库 / 遗物快照，最多 40 场可导出 JSON |
| 事件小游戏 | QTE 打字追逐 + 八数码拼图，作为节拍器不替代主战斗 |

### 自测与工具

| 脚本 | 用途 |
| --- | --- |
| `scripts/full_selftest.py` | Playwright 全流程：开局→探索→战斗→Boss，5 条路线策略汇总 |
| `scripts/boss_selftest.py` | Boss 仪式多场自测，汇总 lab |
| `scripts/hunt_selftest.py` | 躲藏空转 5 场，检测「怪不找人」回归 |
| `scripts/dump_lab_server.py` | 静态服务器 + `/__dump-lab` 把浏览器 lab JSON 落盘 |
| `scripts/gen_ui_mock.py` | AI 生成 UI 概念 mock（多模态 hub） |
| `scripts/ark_chat.py` | 火山方舟 LLM 聊天辅助（Key 放仓库根 `.env`，勿提交） |

## 文档入口

| 文档 | 用途 |
| --- | --- |
| [docs/design/织梦频道_channel_dream_策划案与招标书.md](./docs/design/织梦频道_channel_dream_策划案与招标书.md) | 主策划 / 招标书 |
| [docs/open-questions.md](./docs/open-questions.md) | 存疑（能力值、视野预警等） |
| [docs/design/archive/](./docs/design/archive/) | 历史稿 |

## 协作约定（最短版）

1. 从 `main` 开 `feature/` 或 `fix/` 分支，PR 合入  
2. 新长文进 `docs/`，不要堆仓库根  
3. 大玩法改动先更新 `docs/open-questions.md`  
4. 勿提交密钥与本机大文件  

完整约定见 [CONTRIBUTING.md](./CONTRIBUTING.md)。
