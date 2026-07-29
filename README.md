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
| 大地图 / 房间 | 种子伪随机连通平面图；「换平面图」；祭坛/仪式不进随机图 |
| 战斗 | 走位 + 卡牌；意图红格；STS 风格结束层；战斗内「主页」回菜单（不记败） |
| 恢复 / 曲线 | 软化战斗曲线；战后/静室回血；低血慎战与撤退 |
| 音频 | 顶栏「音乐：开/关」 |
| 存档 | localStorage；含 `runSeed` / `roomLayout` |

细则： [cabin-slice/README.md](./cabin-slice/README.md)、[data/run-scheme.md](./cabin-slice/data/run-scheme.md)、[data/cards-rules.md](./cabin-slice/data/cards-rules.md)

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
