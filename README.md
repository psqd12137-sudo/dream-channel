# Dream Channel · 山屋频道

跨电脑协作的游戏制作仓库：可玩竖切片 demo（`cabin-slice/`）+ 策划文档。

## 快速开始

换电脑请直接看：**[另一台电脑一键拉取.md](./另一台电脑一键拉取.md)**

本机已有仓库时：

```bash
cd cabin-slice
python3 -m http.server 8787
```

浏览器打开：http://127.0.0.1:8787/ → 点「打开电视机」

## 当前 demo 状态（Run Scheme v3）

竖切片 `cabin-slice/` 是一款 **放置 × 走位** 的 roguelike 网页 demo：

- 出牌 = 往场地放道具（地刺、盐圈、闪光雷…），移动引怪踩陷阱削韧性
- 每间房独立网格战场（墙、高低差、传送格），意图用红/蓝格子明示
- 开局遗物二选一、牌库成长、中点保底遗物；Boss 可仪式熄锚或击杀通关
- **下一轮**：用拼图 / 横版搜物等解密事件调剂节奏（减少纯战斗与平铺弹窗）
- 详细玩法见 **[cabin-slice/README.md](./cabin-slice/README.md)**

## 目录

| 路径 | 说明 |
| --- | --- |
| `cabin-slice/` | 可玩竖切片（HTML / CSS / JS + JSON 数据） |
| `Dream Channel 游戏策划案.md` | 主策划案 |
| `Dream Channel - 阈限秘境 游戏策划案.md` | 阈限向草案 |
| `个人片库 WebUI 技术方案.md` | 相关技术笔记 |

## 版本习惯

- 小步提交：写清「改了什么 / 为什么」
- 阶段节点可打 tag，例如 `v0.1-kids-tv`
- 换电脑：先 `git pull`，再改，再 `git push`

## 推到 GitHub

仓库已关联 `origin`。日常推送：

```bash
git add -A
git commit -m "你的提交说明"
git push origin main
```

本机若还没登录 GitHub CLI，见 **[另一台电脑一键拉取.md](./另一台电脑一键拉取.md)** 或：

```bash
./.tools/gh_2.96.0_macOS_arm64/bin/gh auth login
```

## 注意

- 游戏存档在浏览器 `localStorage`（键名 `cabin-run-v3`），不会进 Git
- 不要提交密钥、本地下载大文件、虚拟环境
- 已忽略：`downloads/`、`.tools/`、`Quark_Magnet_Search/`
