# 织梦频道 · channel dream

正式名：**《织梦频道 channel dream》**（日常可简称 **channel**）。  
本仓库是跨电脑协作的制作库：可玩竖切片 demo（`cabin-slice/`）+ 策划文档。

**美学主打**：怀旧 · 邪典 · 荒诞——有点像 *Superjail* 那种「儿童节目外壳 + 失控的超现实内核」。不是温馨合家欢，也不是马里奥派对。

## 快速开始

换电脑请直接看：**[另一台电脑一键拉取.md](./另一台电脑一键拉取.md)**

本机已有仓库时：

```bash
cd cabin-slice
python3 -m http.server 8787
```

浏览器打开：http://127.0.0.1:8787/ → 点「打开电视机」

## 当前 demo 状态（山屋切片 · Run Scheme v3）

`cabin-slice/` 是 channel 里的一集可玩切片：**放置 × 走位** roguelike 网页 demo：

- 出牌 = 往场地放道具（地刺、盐圈、闪光雷…），移动引怪踩陷阱削韧性
- 每间房独立网格战场（墙、高低差、传送格），意图用红/蓝格子明示
- 开局遗物二选一、牌库成长、中点保底遗物；Boss 可仪式熄锚或击杀通关
- **下一轮**：少量解密/考验调剂节奏（Haunt 式，克制）；第二视角美学定 **3D 微缩景深**
- 详细玩法见 **[cabin-slice/README.md](./cabin-slice/README.md)**

## 目录

| 路径 | 说明 |
| --- | --- |
| `cabin-slice/` | 可玩竖切片（HTML / CSS / JS + JSON 数据） |
| **[织梦频道_channel_dream_策划案与招标书.md](./织梦频道_channel_dream_策划案与招标书.md)** | **完整策划案 / 协作招标书（现行主文档）** |
| `Dream Channel 游戏策划案.md` | 早期观测者宇宙策划（历史文件；产品名与范围以招标书为准） |
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
