# 协作指南 · 织梦频道 channel dream

适合多人并行。改代码前请先读仓库根 [README.md](./README.md) 与 [docs/open-questions.md](./docs/open-questions.md)。

## 仓库分层

```text
dream-channel/
  README.md                 # 总览与快速开始
  CONTRIBUTING.md           # 本文件
  docs/                     # 策划、存疑、安装说明
    open-questions.md
    setup/
    design/                 # 现行招标书 + 玩法概念 + archive/
    tech/                   # 技术方案与自测
  cabin-slice/              # 可玩竖切片（HTML/CSS/JS）
    data/                   # JSON + 切片内设计短稿
    js/ css/ assets/ scripts/
```

- **文档**进 `docs/`，不要再往仓库根堆新的长篇 `.md`  
- **可玩实现**只在 `cabin-slice/`（若日后迁到 `apps/cabin-slice/`，以 README 为准）  
- **存疑议题**先写 `docs/open-questions.md`，避免半截大重构

## 分支与提交

1. 从最新 `main` 拉分支：`feature/短名` 或 `fix/短名`  
2. 小步提交：说明「改了什么 / 为什么」（中文或英文均可）  
3. 用 PR 合入 `main`；避免直接强推 `main`  
4. 不要提交：密钥、`.env`、本地下载大包、`node_modules`、浏览器存档  

## 本地跑切片

```bash
cd cabin-slice
python3 -m http.server 8787
```

打开 http://127.0.0.1:8787/ ，硬刷新后再测。

新机器流程见 [docs/setup/另一台电脑一键拉取.md](./docs/setup/另一台电脑一键拉取.md)。

## 改玩法时

| 你要动的 | 先看 |
| --- | --- |
| 卡牌 / 奖励 | `cabin-slice/data/cards.json`、`cards-rules.md` |
| 房间 / 地图布局 | `rooms.json`、`run-scheme.md` |
| 难度 / Boss | `pressure.json`、`bosses.json` |
| 成长轴大改 | **先更新** `docs/open-questions.md` 再动代码 |

## 自测

- 手动：开新局 → 重开看种子号 → 进战看红格 → 主页/音乐按钮  
- 脚本（需 Playwright）：`cabin-slice/scripts/full_selftest.py`、`boss_selftest.py`
