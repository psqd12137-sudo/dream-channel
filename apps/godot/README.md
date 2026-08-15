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
7. 节目测试台现含最大地图战斗意图、横版跳跃收集、八数码拼图、3D 微缩搜物，以及直接复用正式黄色扩建格、票根选择、旋转与摆放规则的 Kenney 桌模 PCG 测试。

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

大地图与战斗地图镜头操作：

- 左键：移动、选择格子或放置卡牌
- 左键拖动战场空白：围绕整个棋盘中心做水平旋转，俯角固定；未形成拖动时仍按普通地格点击处理
- 从底部拖动放置牌时会拉出目标箭头，箭头落到有效格并释放即可布置；拖到战场外会返回手牌，卡牌本体不会遮挡棋盘
- 鼠标悬停手牌：卡牌上浮放大，显示插画与完整一些的效果说明
- 放置牌再次点击、右键、`Esc` 或“取消选牌”：退出金色摆放模式并恢复绿色移动目标
- 中键拖动：平移地图（探索、房间摆放与战斗均可用）
- 鼠标滚轮：以指针位置为中心缩放
- 顶栏“地图复位/镜头复位”：恢复当前地图的完整取景；扩建预览重建时会保留玩家当前缩放和平移

战斗格使用深色格缝和交替纸面色；蓝框表示敌人路径，红框表示必伤格，绿色角标表示可移动，金色角标表示卡牌目标，`H1/H2` 表示可站立的家具高台，`A/B` 表示传送门端点。

当前战场不再用整块高立方体表示高低差：`H1/H2` 会从现有 Quaternius 家具中确定性选取桌、沙发、炉具、书架、冰箱或壁炉作为高度载体，并保留一层逻辑站立面；移动仍按战斗网格结算，所以玩家和敌人可以稳定站在资产顶部。绿色立方体只保留给不可通行的墙或柱。传送门以紫色环和成对字母显示；玩家站上门格后仍可正常移动、出牌或结束回合，也可额外支付一次移动费用点击成对端点或右栏“穿门”按钮。敌人只有在寻路选择门边时穿门，强制位移落到门格仍会触发传送，出口已有单位也不阻挡穿门。盖屋时，所选房间会作为微缩预览直接出现在扩建格中，点击“旋转 90°”会实时旋转该预览及门位。

纸傀儡现与已采纳的 Web 规则一致：傀儡占据格子并成为敌人优先目标；敌人花费攻击行动力打掉它后，若还有剩余行动力会继续本回合；追逐傀儡途中踩中伤害陷阱会额外触发 `纸影连击 +1`。意图文案与场内纸片人模型会明确显示这次攻击由傀儡承受。

## CC0 房间微缩布景

首轮房间布景使用 Quaternius 的 [Ultimate House Interior Pack](https://quaternius.com/packs/ultimatehomeinterior.html) 精选子集，许可证为 CC0 1.0。仓库只保留 Demo 实际使用的 12 个 FBX 和原始许可文本，来源清单见 `assets/quaternius/ultimate_house_interior/SOURCE.md`。

大地图房间壳体使用 [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) 的 CC0 精选 GLB：低矮木地板、薄墙、门洞、转角和楼梯。它被 `scenes/pcg_hand_layout_lab.tscn` 与正式摆房测试入口共用，来源、精选范围和原始许可见 `assets/third_party/kaykit_dungeon/SOURCE.md`。

[Kenney Mini Dungeon](https://kenney.nl/assets/mini-dungeon) 仍保留为战斗地图的柱子、可站立地形块与掩体候选；[Quaternius Ultimate Modular Ruins](https://quaternius.com/packs/ultimatemodularruins.html) 保留为废墟题材候选。二者不会再作为当前大地图房间壳体。

- `hall / west_wing / cellar / parlor` 对应计划中的长廊、西厢、地窖和会客室示范房。
- 客厅、厨房、书房、卧室与温室复用同一套可配置布景；未知房不会实例化家具，避免提前泄露内容。
- `scripts/room_art_registry.gd` 只决定模型、位置、旋转与微缩比例；门向、战斗格、房间规则和 Lili 身份资产保持独立。
- 模型丢失或未导入时会发出警告并保留原有程序白盒，不阻塞玩法。

## CC0 临时角色模型

战斗与大地图中的玩家暂用 Quaternius `Ultimate Animated Character Pack` 的 `Casual_Female`，怪物暂用 `Cute Animated Monsters Pack` 的 `Demon`。两者都是 CC0 glTF，并通过 `data/presentation_manifest.json` 配置模型路径、比例和动画名称：

- 待机：玩家和怪物分别循环原模型的 `Idle`；临时模型现按此前尺寸的 50% 显示，逻辑占格不变
- 移动：房间行走和战斗逐格移动期间播放 `Walk`，角色根节点同时平滑移动并转向目标格；移动结束后会保留最后朝向，地图或战场重建、切回待机都不会自动回正
- 攻击/受击：玩家使用 `Punch / RecieveHit`，怪物使用 `Bite_InPlace / HitRecieve`
- 未揭示怪物仍使用原有暗色剪影，进入视野后才切换到 3D 模型

`scripts/character_presenter.gd` 保留原 2D 帧动画作为模型加载失败时的后备。以后替换正式 3D 角色只需更新清单中的 `model_path`、缩放、朝向和 `animation_map`，战斗规则与棋盘移动不需要重写。来源与许可见 `assets/quaternius/animated_characters/SOURCE.md`。

## 手调战斗 UI

打开 `scenes/combat_ui_layout.tscn`。这个场景以 1280 × 800 的设计分辨率显示战斗 HUD 的五个布局区域：`IntentArea`（敌人意图）、`ActionArea`（右侧行动栏）、`HandArea`（底部手牌）、`DeckArea`（抽牌堆）和 `DiscardArea`（弃牌堆）。在 2D 视图中选中节点，用移动工具拖动，或在 Inspector 的 `Layout / Transform` 修改 Position 与 Size，保存后主游戏会读取这些 Rect；不要重命名这五个节点。

当前第一版已接入 `E:/doc/channel doc/ai/1x` 中的红、蓝、黄电视卡背，以及事件与行动面板图集。手牌按 `HandArea` 自动横向展开并形成轻微弧线；抽牌堆和弃牌堆会显示实时数量。原始图集保存在 `assets/ui/channel_concept/`，后续可以继续切分生命条、攻击/移动/搜索图标，而不需要改战斗规则。

战斗视窗会占用原右侧卡牌栏和底部导播栏的空间；战斗导播已移除，状态文字不再遮挡手牌。卡牌保持固定宽高比，悬浮放大时边框、字体、内边距和插画使用同一倍率，插画采用等比例 `contain` 显示而不会被拉伸。

### 手调全部房间

打开 `scenes/room_layout_lab.tscn`。这里以 6 × 4 编辑地图放置了完整的 24 个房间；已有布景的 `Hall / Parlor / WestWing / Cellar` 可作为参考，其余房间是等待布置的可编辑纸盒单元。选中一个房间，在其下添加或拖入 FBX；再选中家具，在 Inspector 的 `Transform > Position / Rotation / Scale` 调整，最后保存场景。

要让主游戏读取新家具，请把家具节点加入 `room_prop` 组（Node 面板的 Groups）。运行时会按房间 ID 复制该组中的直接子节点；因此布局场景是房间美术的唯一来源，而不是再去改 `room_art_registry.gd` 的硬编码坐标。金色短条是门洞禁区，单个房间的可用底盘约为 `3.05 × 3.05`，家具应保持在此范围内。

### 微缩箱庭美术对比

打开 `scenes/diorama_art_lab.tscn` 可以手调三组完全隔离的样板：`CurrentBaseline` 是现有软装与几何墙体，`KenneyMiniDungeon` 是桌面模型候选，`QuaterniusRuins` 是破损墙体、石拱门与资产高差候选。每个模型都是场景树里的真实节点，可直接在 Inspector 修改 Transform；这份场景不会被主游戏当作房间布局读取。

运行项目后，在标题页展开“节目测试台”，点击“桌模扩建 PCG”进入正式大地图摆放测试。A/B/C 单格场景仍可直接运行 `scenes/diorama_art_lab.tscn` 检查资产；其中 Modular Ruins 只保留为历史对比，不再用于当前 PCG 桌模方案。

### PCG 连片箱庭实验

`scenes/pcg_diorama_stitch_lab.tscn` 保留为自动 Seed 整体构图测试；玩家实际评审入口改为标题页“节目测试台 → 桌模扩建 PCG”。该入口直接进入正式 `explore/build` 阶段：点击黄色扩建格、选择票根、按“旋转 90°”查看完整 1/3/5 格 Kenney 预览，确认“摆下”后再从真实 `room_rules.placed` 重算整栋外观，而且不会写入本局存档。

当前 PCG 绘制统一使用 Kenney Mini Dungeon 的 `floor / wall / wall-half / wall-opening / gate / stairs / column` 与桌椅箱桶道具；Modular Ruins 的石拱、破墙和圆柱已经从这条测试链路移除。

- 固定用 `R00 · 1格 → R01 · 5格` 开场，直接证明先放一格房、再接五格房的组合；后续继续混合 3 格和其他 1/5 格形状。
- 同一房间的相邻单元删除内墙，地板连续铺设。
- 房间生成时使用的连接边变成 Kenney `wall-opening` 与 `gate`；后来偶然贴合但不连通的跨房边保留完整墙。
- 占用并集的外边界生成连续 `wall / wall-half` 轮廓和凸角 `column`；朝镜头一侧保留剖视开口。
- 第一个五格房作为整体抬高，而不是随机抬高单格；连接高低区时自动补楼梯。
- 装饰按房间而非按单格投放，每房只选一个焦点道具，避免 PCG 把资产均匀撒满棋盘。
- 每个房间拥有独立视觉根节点和编号；重建时按房间顺序整块落位，因此五格房会作为一个建筑整体出现，不会逐格散落。

实验室支持“换一个 Seed”整栋重建并重播逐房落位动画，也可切回 A/B/C 单格样板。它验证的是网格版“建筑化学”：拓扑拼接、连续轮廓、门洞、高差和装饰密度；并不等同于 Tiny Glade 的无网格程序化网格、曲墙、屋顶变形与材质融合。正式数据中的 `room_rules.placed` 已用独立 `instance_id` 区分每间房，并要求跨房接触面门对门；当前正式摆放动画也会同步落下一个多格房的全部格子。把实验室资产拼接器接到这份数据、补齐最终转角/屋顶/门窗变体后，才能替换正式大地图的占位美术。

### 正式地图手摆模拟

打开 `scenes/pcg_hand_layout_lab.tscn`，只编辑场景树 `Layout` 下的房间节点；不要移动自动生成的 `GeneratedMap`。初始样板按正式摆放顺序提供 `1→5→3→1→3→5→1` 七间房；该场景现在作为编辑器构图辅助，实际游戏内旋转与摆放效果请使用标题页“桌模扩建 PCG”。

1. 选中一个 `Layout/Rxx_*` 房间节点，使用 Godot 移动工具拖动 X/Z；生成器按 `1.55m` 为一格自动吸附到最近格。建议在编辑器顶部开启移动吸附并把步长设为 `1.55`。
2. 绕 Y 轴旋转房间；生成器按最接近的 `90°` 读取朝向。建议把旋转吸附设为 `90°`。
3. 在 Inspector 修改 `shape_id` 选择 `single / line3 / l3 / plus5 / t5 / p5 / stair5 / u5`，修改 `room_id` 作为房间实例标识，勾选 `elevated` 生成整房高台与连接楼梯。
4. 要增加房间，选中最后一个房间节点按 `Ctrl+D`，改成唯一 `room_id` 后拖到已有建筑旁边。`Layout` 的节点顺序就是模拟的正式摆放顺序；除第一间外，每间房会从与先前房间相邻的边中选择一个入口门洞，其余额外贴边保留分隔墙。
5. 红色标签表示重叠或没有连接到此前房间；消除红字后再运行场景查看整房落位动画。房间编号和错误标签只用于评审，正式接入可以关闭。

这份场景保存的是房间根节点的形状、位置、旋转和高差，不保存自动生成的墙地板节点，因此可以安全反复手摆。评审通过后，再让正式大地图的 `room_rules.placed` 生成同样的描述并复用这套拼接器。

### 1 / 3 / 5 格房间

当前地图已接入多格房间：1 格用于空房、恢复和简单战斗等节奏调节；3 格支持长条与 L 形，承载追逐、抓人和拼图；5 格使用十字、T、P、阶梯与 U 形，作为大型精英战斗。进入一个多格房的任意占用格都会进入同一房间事件，完成后移动到该房间其他格不会重复触发。完整分配与后续规则见 `ROOM_FOOTPRINT_DESIGN.md`。

房间占用形状与门型是两个独立维度：两个房间即使都使用 `line3`，也可能分别抽到 `end` 与 `+` 门型；只有房间、门型和旋转都相同，外门方向才会相同。运行时已经把门型解析成逐格世界边表 `open_edges`：每个开启方向只选择一个稳定的外沿门位，随房间旋转、落位并与邻房双向校验，不会再把同方向整排格子全部打开。

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
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/room_footprint_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/multi_room_build_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_patrol_intent_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_vision_state_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/enemy_turn_animation_regression.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/completion_labs_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/diorama_art_lab_smoke.gd
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path $godotProject --script res://tests/pcg_diorama_stitch_smoke.gd
```

`latest_3d_smoke.gd` 覆盖二选一预兆、三张票根、摆下后隐藏、进入后揭示、3D 房屋网格与 3D 战斗网格；`dynamic_effects_smoke.gd` 额外覆盖房间翻转悬落、角色移动、未知揭示与输入锁。

截图脚本会把视觉校验图写入本机 `artifacts/`；该目录与 `.godot/` 一样属于可再生成产物，不提交到仓库。
��到仓库。
