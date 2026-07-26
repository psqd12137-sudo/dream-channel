# Dream Channel · 山屋频道

跨电脑协作的游戏制作仓库：竖切片 demo（`cabin-slice/`）+ 策划文档。

## 快速开始

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
- 阶段节点可打 tag，例如 `v0.1-kids-tv`
- 换电脑：先 `git pull`，再改，再 `git push`

## 注意

- 存档在浏览器 `localStorage`（键名见 `cabin-slice/README.md`），不会进 Git
- 不要提交密钥、本地下载大文件、虚拟环境
