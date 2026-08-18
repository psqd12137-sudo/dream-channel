# web 发布版归档（releases）

本目录归档 **Web/桌面发布产物**，与 `web/` 活跃源码分开存放，避免堆积在工作区顶层。

## 发布版

| 文件 | 内容 | 构建日期 | 说明 |
| --- | --- | --- | --- |
| `CabinSlice_织梦频道.exe` | 织梦频道桌面版（Windows 单机 exe，内嵌 web） | 2026-08-12 | **Web/桌面规则基准**；玩法核对以它的实际行为为准 |
| `CabinSlice_山屋惊魂.exe` | 山屋惊魂实验版（Windows 单机 exe） | 2026-08-02 | 早期实验桌面包 |

> 两个 exe 均被 `.gitignore` 忽略（`CabinSlice_*.exe`），不进入 git 仓库，仅作本地发布物。SHA-256 见 [Web README](../README.md)。

## lab 自测日志（lab_logs/）

`lab_logs/` 存放 Playwright 等自测脚本的运行产物（`lab-*.json`、`lab-*.log`、`cabin-lab-*.json`）。这些是实验记录，不进入 git（`.gitignore` 忽略 `web/lab-*.json` 与 `web/cabin-lab-*.json`），保留用于对照分析。
