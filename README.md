# Dream Channel · 山屋频道

跨电脑协作的游戏制作仓库：竖切片 demo（`cabin-slice/`）+ 策划文档。

## 快速开始

换电脑请直接看：**[另一台电脑一键拉取.md](./另一台电脑一键拉取.md)**

本机已有仓库时：

```bash
cd cabin-slice
python3 -m http.server 8787
```

浏览器打开：http://127.0.0.1:8787/

## 目录

| 路径 | 说明 |
| --- | --- |
| `cabin-slice/` | 可玩竖切片（HTML / CSS / JS） |
| `Dream Channel 游戏策划案.md` | 主策划案 |
| `Dream Channel - 阈限秘境 游戏策划案.md` | 阈限向草案 |
| `个人片库 WebUI 技术方案.md` | 相关技术笔记 |

## 版本习惯

- 小步提交：写清「改了什么 / 为什么」
- 阶段节点可打 tag，例如 `v0.1-kids-tv`（本仓库已打）
- 换电脑：先 `git pull`，再改，再 `git push`

## 推到 GitHub（只需做一次）

本机若还没登录 GitHub CLI：

```bash
cd "/Users/bytedance/Documents/claw/new channel"
./.tools/gh_2.96.0_macOS_arm64/bin/gh auth login
```

登录后创建私有仓库并推送：

```bash
./.tools/gh_2.96.0_macOS_arm64/bin/gh repo create dream-channel --private --source=. --remote=origin --push
git push origin v0.1-kids-tv
```

另一台电脑：

```bash
git clone https://github.com/<你的用户名>/dream-channel.git
cd dream-channel/cabin-slice
python3 -m http.server 8787
```

首次在本仓库提交前，建议设置本仓库作者（不会改全局）：

```bash
git config user.name "鲁清"
git config user.email "你的邮箱或 GitHub noreply 邮箱"
```

## 注意

- 存档在浏览器 `localStorage`（键名见 `cabin-slice/README.md`），不会进 Git
- 不要提交密钥、本地下载大文件、虚拟环境
- 已忽略：`downloads/`、`.tools/`、`Quark_Magnet_Search/`
