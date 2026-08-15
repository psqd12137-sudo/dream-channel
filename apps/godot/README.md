# Channel Godot 4 Client
状态：正式客户端事实（核对日期：2026-08-15）。

这是《织梦频道》当前唯一正式开发主线。玩法规则、运行数据、交互、3D 表现和发布质量都在本目录落地并由 Godot 回归测试约束。`cabin-slice/` 只保留为低成本玩法实验场；其中的行为不会自动成为正式规则，也不要求与 Godot UI 保持一致。

## 打开项目与场景

- Godot 项目：`apps/godot/project.godot`
- 当前 3D 主场景：`apps/godot/channel_3d.tscn`
- 旧版 2D 对照场景：`apps/godot/main.tscn`

`application/run/main_scene` 已通过 Godot MCP 设置为 `res://channel_3d.tscn`。在编辑器里按 F6 可运行当前场景，按 F5 可运行项目主场景。

```powershell
D:\godot\Godot_v4.7.1-stable_win64.exe --path "\\192.168.1.2\SharedFolder\new channel\apps\godot" --editor
```

Godot 4 可以直接读取 Windows UNC 网络路径。若编辑器导入或文件监听在网络盘上变慢，可将共享目录映射成盘符，或在本地 clone 后打开；项目内资源统一使用 `res://`，因此无需修改场景和脚本。

## 历史 Web 参考快照

`data/exe_snapshot/` 保存了一份 2026-08-13 的 Web 内容导入快照，用于追溯早期玩法和兼容既有数据。它不是当前规则权威，也不应反向覆盖 Godot 中已测试的正式行为。对应的可执行文件是 `cabin-slice/CabinSlice_织梦频道.exe`：

- 最后写入：2026-08-11 19:36:02 UTC
- 大小：37,446,144 bytes
- SHA-256：`EEC4C574CC227FB966D39265A31E25F4D6875557C6BB09BB771E6760CC11DC03`
- 本地运行形态：EXE 启动 Go HTTP 服务，页面位于 `http://127.0.0.1:17887/`

精确来源记录在 `data/exe_snapshot/source_manifest.json`。Godot 目前仍从本地快照读取部分内容；后续修改这些数据时以 Godot 需求为准，并同步增加相应测试。

## 当前正式玩法（核对日期：2026-08-15）

1. Web 风格主页提供“打开电视机”“新手教学”和可展开的节目测试台。
2. 开局先从两张“行前预兆”中选择一张；玄关计入行程，初始进度为 `1/12`。
3. 在等距 3D 屋面点击黄色扩建格；每次抽三张隐藏类型的房间票根，旋转并严格匹配双边门。
4. 角色走进房间才揭示内容，完成事件或战斗后才增加行程。
5. 惊吓时间使用独立 3D 战斗网格；每回合固定获得 `5` 点行动力，不再投掷 `0/1/2` 速度骰，并包含手牌、图形化生命/韧性/敌人意图、伏击/视线、追击与格内陷阱。
6. 无视野怪物会搜索最后目击点 5 回合，之后持续巡视；蓝色编号显示逐格路线，敌方回合播放实际移动/攻击动画。
7. 节目测试台现含最大地图战斗意图、横版跳跃收集、八数码拼图与 3D 微缩搜物。

详细的已完成/待补齐矩阵见 `WEB_GODOT_PARITY.md`。
后续战斗节奏、固定微缩模型与主循环接入计划见 `NEXT_PHASE_PLAN.md`。

## Unity 动态效果基线

- 摆放房间：完整房间作为一个根节点翻转落位，沿用 Unity 的悬高 `0.65` 格、初始 `94%` 缩放、`0.25s` 二次缓出，并补一段 `0.12s` 轻微落地回弹；候选房间会随每次旋转按钮即时转到对应门向，即使连续快速点击也不会失步。
- 进入房间：莉莉按 Unity 的每格 `0.25s` 平滑移动，落脚使用 `0.12s` 收势。
- 进入战斗房：战场地块先从平面展开构建，随后玩家与怪物从两侧落入各自格位；演出期间锁定输入，完成后才允许操作。
- 未知揭示：角色抵达后才执行 `0.10s + 0.10s` 的双段翻面，翻面中点切换为房间正面；摆放动画不会提前泄露内容。
- 演出期间会锁定摆放、进入、结算和战斗输入。脚本导出项 `animation_duration_scale` 可在 Inspector 设为 `0`（测试即时完成）或大于 `1`（慢动作校验）。

## 3D 结构

- 根节点：`Node3D`
- 镜头：正交 `Camera3D`，通过 `SubViewportContainer` 只渲染在 HUD 安全区内
- 房间、墙、门边、桥、扩建格、角色、战斗格、障碍和陷阱：运行时生成的 `MeshInstance3D`
- UI：`CanvasLayer + Control`，只负责承载 Web 信息层和把点击转发给 3D 世界
- 玩法入口：`scripts/channel_3d.gd`
- UI 入口：`scripts/channel_3d_hud.gd`
- 战斗规则：`scripts/combat_rules.gd`
- 最新 Web 数据适配：`scripts/web_content_adapter.gd`

战斗镜头操作：

- 左键：移动、选择格子或放置卡牌
- 放置牌再次点击、右键、`Esc` 或“取消选牌”：退出金色摆放模式并恢复绿色移动目标
- 中键拖动：平移棋盘
- 鼠标滚轮：以指针位置为中心缩放
- 顶栏“镜头复位”：恢复当前地图的完整取景

战斗格使用深色格缝和交替纸面色；蓝框表示敌人路径，红框表示必伤格，绿色角标表示可移动，金色角标表示卡牌目标，`H1/H2` 表示高台，`A/B` 表示传送门端点。

当前战场以灰度区分高度：浅灰为地面、中灰为 `H1`、深灰为 `H2`，绿色立方体为墙或柱。传送门以紫色环和成对字母显示；玩家走上入口后必须在右栏主动选择“穿过”或“留在这里”，不会被立即传送。盖屋时，所选房间会作为微缩预览直接出现在扩建格中，点击“旋转 90°”会实时旋转该预览及门位。

## CC0 房间微缩布景

首轮房间布景使用 Quaternius 的 [Ultimate House Interior Pack](https://quaternius.com/packs/ultimatehomeinterior.html) 精选子集，许可证为 CC0 1.0。仓库只保留 Demo 实际使用的 12 个 FBX 和原始许可文本，来源清单见 `assets/quaternius/ultimate_house_interior/SOURCE.md`。

- `hall / west_wing / cellar / parlor` 对应计划中的长廊、西厢、地窖和会客室示范房。
- 客厅、厨房、书房、卧室与温室复用同一套可配置布景；未知房不会实例化家具，避免提前泄露内容。
- `scripts/room_art_registry.gd` 只决定模型、位置、旋转与微缩比例；门向、战斗格、房间规则和 Lili 身份资产保持独立。
- 模型丢失或未导入时会发出警告并保留原有程序白盒，不阻塞玩法。

### 手调全部房间

打开 `scenes/room_layout_lab.tscn`。这里以 6 × 4 编辑地图放置了完整的 24 个房间；已有布景的 `Hall / Parlor / WestWing / Cellar` 可作为参考，其余房间是等待布置的可编辑纸盒单元。选中一个房间，在其下添加或拖入 FBX；再选中家具，在 Inspector 的 `Transform > Position / Rotation / Scale` 调整，最后保存场景。

要让主游戏读取新家具，请把家具节点加入 `room_prop` 组（Node 面板的 Groups）。运行时会按房间 ID 复制该组中的直接子节点；因此布局场景是房间美术的唯一来源，而不是再去改 `room_art_registry.gd` 的硬编码坐标。金色短条是门洞禁区，单个房间的可用底盘约为 `3.05 × 3.05`，家具应保持在此范围内。

## 与 Unity 版的隔离

- 不包含也不修改 `Channel_Teil` Unity 工程。
- 没有复制 Unity 的 `.meta`、Prefab、Scene、Library、Package 或 Catalog。
- Godot 工程只复用玩法概念和 Web 数据；旧 2D 场景也被保留，便于比对。
- Unity 版仍是另一条实现路线；`apps/godot/` 是与其隔离的 Godot 客户端。

## 自检

```powershell
$godotProject = "\\192.168.1.2\SharedFolder\new channel\apps\godot"
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/smoke_test.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/web_snapshot_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/combat_mechanics_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/latest_3d_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/battle_view_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/dynamic_effects_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/quaternius_room_art_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_patrol_intent_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_vision_state_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_turn_animation_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/completion_labs_smoke.gd
```

`latest_3d_smoke.gd` 覆盖二选一预兆、三张票根、摆下后隐藏、进入后揭示、3D 房屋网格与 3D 战斗网格；`dynamic_effects_smoke.gd` 额外覆盖房间翻转悬落、角色移动、未知揭示与输入锁。

截图脚本会把视觉校验图写入本机 `artifacts/`；该目录与 `.godot/` 一样属于可再生成产物，不提交到仓库。
