# 织梦频道文档地图

本文定义正式文档范围、权威等级和冲突处理方式。根目录 README 只负责导航；实现细节留在对应客户端目录。

## 权威等级

从高到低依次为：

1. **现行决策**：[主策划](./design/织梦频道_channel_dream_策划案与招标书.md) 中明确标为已确认的内容。
2. **未决登记**：[未决设计](./open-questions.md)。这里表示问题尚未拍板，不应被任一客户端的临时实现覆盖。
3. **客户端事实**：[Web README](../cabin-slice/README.md)、[Godot README](../apps/godot/README.md) 及可执行测试。只说明该客户端已经做到什么。
4. **规则细则与技术说明**：客户端数据目录和 `docs/tech/` 中的文档。不得与更高等级结论冲突。
5. **计划与分析**：路线图、完成度对照、概念分析。它们表达下一步或候选方向，不表示已经实现或拍板。
6. **历史归档与生成副本**：只供追溯，没有决策权。

如果两份同等级文档冲突，应在 [未决设计](./open-questions.md) 登记并指定负责人，不要自行选一份当结论。

## 正式入口

### 产品与设计

| 文档 | 用途 | 状态 |
| --- | --- | --- |
| [现行主策划](./design/织梦频道_channel_dream_策划案与招标书.md) | 产品定位、体验支柱、范围和里程碑 | 现行决策 |
| [未决设计](./open-questions.md) | 尚未拍板的问题与临时口径 | 持续维护 |
| [玩法拓展与设计轴](./design/玩法拓展概念与设计轴.md) | 设计分析和候选拓展顺序 | 分析材料 |
| [多人节目终局设想](../cabin-slice/data/multiplayer-haunt-sketch.md) | 多人、半场改剧本和整图终局概念 | 远期短稿 |
| [历史归档说明](./design/archive/README.md) | 旧方案边界与索引 | 只读说明 |

### Web 客户端

| 文档 | 用途 |
| --- | --- |
| [Web README](../cabin-slice/README.md) | 运行方式、当前玩法和桌面封装 |
| [Run Scheme](../cabin-slice/data/run-scheme.md) | Web 战斗、地形和节奏细则 |
| [卡牌规则](../cabin-slice/data/cards-rules.md) | 出牌、奖励和卡牌清单 |
| [Web 技术与自测](./tech/技术方案与自测.md) | Web 架构、存档、遥测和测试脚本 |

`cabin-slice/desktop/launcher/web/` 是桌面打包时生成或复制的 Web 内容。其中的 Markdown 副本不参与编辑，也不作为规则依据。

### Godot 客户端

| 文档 | 用途 | 状态 |
| --- | --- | --- |
| [Godot README](../apps/godot/README.md) | 打开方式、操作、结构和测试 | 客户端事实 |
| [Godot 完成度与 Web 历史参考](../apps/godot/WEB_GODOT_PARITY.md) | Godot 正式完成度及 Web 候选想法 | 客户端事实 |
| [下一阶段计划](../apps/godot/NEXT_PHASE_PLAN.md) | Godot 实施顺序 | 计划，不代表完成 |
| [表现资产包](../apps/godot/PRESENTATION_PACK.md) | 角色、动画、道具和装饰导入契约 | 技术接口 |
| [房间占格与节奏分层](../apps/godot/ROOM_FOOTPRINT_DESIGN.md) | 1/3/5 格房间规模、当前分配与编辑规则 | 客户端事实 |

### 协作与环境

| 文档 | 用途 |
| --- | --- |
| [协作指南](../CONTRIBUTING.md) | 文件归属、测试和 Git 约定 |
| [Agent 交接区](./handoffs/README.md) | 每次功能提交的改动、验证和后续工作记录 |
| [新电脑接入](./setup/另一台电脑一键拉取.md) | 从 GitHub clone 并运行两个客户端 |
| [Cursor 接入 DeepSeek](./setup/Cursor接入DeepSeek.md) | 可选开发工具配置 |
| [Cursor 接入火山方舟](./setup/Cursor接入火山方舟.md) | 可选开发工具配置 |

## 文件状态标签

新增长文档时，应在标题后尽早写明以下一种状态：

- `状态：现行决策`
- `状态：客户端事实`
- `状态：未决讨论`
- `状态：实施计划`
- `状态：测试报告`
- `状态：历史归档`

文档中的“当前”“最近”“最新版”应附日期、版本号、提交号或文件哈希。无法给出基准时，改写成不依赖时间的描述。

## 不属于正式文档的内容

- `.godot/`、`node_modules/`、工具依赖中的 README。
- `desktop/launcher/web/` 内由源目录复制出的 Markdown。
- `lab-*.md` 等一次性测试报告；若结论仍有效，应提炼到正式文档后保留为测试证据。
- 根目录散落的图片、压缩包、资料库和未登记实验目录。
- 任何只在某台电脑存在、仓库内无法访问的绝对路径引用。
