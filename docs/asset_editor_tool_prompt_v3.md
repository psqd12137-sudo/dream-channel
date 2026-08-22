# 地编工具 v3：换纸板片场载体 + 美学验收线 · 给 Codex

> 状态：实施计划（2026-08-22，v2 已交付但有视觉/比例问题，本次做载体更换 + 美学标准）
> 用法：把本文件全文粘贴给 Codex，让它按「执行步骤」逐条实施。
> 前置：v2 已完成（`godot/scripts/asset_editor_3d.gd`、`asset_diorama_rules.gd`、
> `asset_editor_3d.tscn`、`asset_editor_smoke.gd`、`godot/data/editor/asset_catalog.json`、
> `godot/data/editor/preset_templates/*.json`）。本次是**在 v2 基础上的视觉/资产升级**，
> 不改 v2 已实现的功能交互（画墙、模板拆借、Unity 键位、三档、参照物、聚焦、撤销）。
> Codex 动手前必须读 v2 的文件 + 本文件 + `godot/scripts/pcg_diorama_stitch_lab.gd` 的纸板函数。

## 1. 问题与目标（先认清为什么改）

v2 实测（见 v2 验收截图）暴露三个视觉问题，根源都在**载体**：

1. **墙是 KayKit 地牢厚重砖墙**，不是节目纸盒微缩片场风格 → 一眼出戏。
2. **墙比例过高、封死房间**，看不到内部家具 → 无法做"微缩景观"。
3. **模板加载后墙杂乱堆叠**、往房间内部挤 → 没有片场围合感。

项目正式 PCG 里**已经有成套的程序化纸板片场件**（`pcg_diorama_stitch_lab.gd` 的
`_add_cardboard_wall / _add_cardboard_doorway / _add_cardboard_junction / _add_cardboard_box`），
就是我们要的纸盒+胶带+折边+支撑脚风格。**本次就是把地编工具的墙/门/转角载体换成这套纸板件，
并补上可验收的美学标准。**

目标：打开地编工具 → 加载模板 → 房间是**干净的纸盒布景**：乳白纸板墙、胶带接缝、金色描边、
半开放能看进屋、家具是手作色（felt/painted_wood/clay）——一眼是"荒诞儿童玩具秀的实体微缩片场"，
不是地牢。

## 2. 载体更换规格（核心）

### 2.1 纸板件函数（直接移植，不要重新造）

`pcg_diorama_stitch_lab.gd` 现有（照抄逻辑与参数，改成地编场景可用的独立版本）：
- `_add_cardboard_box(parent, node_name, position, size, color, cast_shadow)`
- `_add_cardboard_wall(node_name, position, yaw, room_index, edge_key, edge_kind)`
- `_add_cardboard_doorway(node_name, position, yaw, room_index, edge_key)`
- `_add_cardboard_junction(node_name, position, height, room_index, edge_keys)`

关键常量（照抄，不要改）：
```gdscript
const KAYKIT_WALL_HEIGHT := 1.08
const KAYKIT_JUNCTION_WIDTH := 0.28
const CARDBOARD_PANEL_THICKNESS := 0.10
const CARDBOARD_DOOR_OPENING := 0.66
const CELL := 1.55
```

纸板调色板（`_toy_show_shell_color`，按 room_index 取模）：
```gdscript
[Color("d6afa5"), Color("9fb9ad"), Color("b9acd0"), Color("d2c27d"), Color("9eb8c7"), Color("d3b89b")]
```

墙/门/转角各子件（含名称与颜色，见 2.2）。**Codex 把这段纸板生成逻辑抽成一个独立可复用类**
（如 `class_name CardboardShellBuilder extends RefCounted`），地编工具与后续可共用，
避免把 200 行塞进 `asset_editor_3d.gd`。

### 2.2 墙段 = 纸板面板（替代 kaykit_wall 系列）

地编工具画墙时，**不再实例化 KayKit 砖墙 gltf**，而是按边界生成纸板件。每个墙段替换为：

```
CardboardWall (Node3D)
├── Panel (BoxMesh)    size=(span, WALL_HEIGHT, PANEL_THICKNESS), 色=base_color
├── TopFold (BoxMesh)  size=(span+0.04, 0.05, PANEL_THICKNESS+0.035), 色=base_color.lightened(0.10)
├── TapeSeam (BoxMesh) size=(0.045, WALL_HEIGHT*0.76, 0.012), 色=Color("e5d49d")
├── BackFoot_+1 (BoxMesh) size=(0.07, 0.11, 0.34), 色=base_color.darkened(0.14), position z=-0.14
└── BackFoot_-1 (BoxMesh) 同上，position z=+0.14
```
- `span = CELL - KAYKIT_JUNCTION_WIDTH = 1.27`
- 墙段位置 y = 0（纸板件自带高度，底部贴地），yaw 取边界轴向（水平 90°/垂直 0°）
- 纸板件规格与项目正式 PCG 完全一致（保证同视觉语言）
- 每个墙段 `set_meta("cardboard_shell", true)`，便于后续统一着色

### 2.3 门洞墙 = 纸板门框（替代 kaykit_wall_doorway）

```
CardboardDoorway (Node3D)
├── Side_-1 / Side_+1 (BoxMesh)  size=(side_width, WALL_HEIGHT, PANEL_THICKNESS), 色=base_color.lightened(0.06)
├── Header (BoxMesh)             size=(CARDBOARD_DOOR_OPENING, header_height, PANEL_THICKNESS)
├── TopFold (BoxMesh)            同墙 TopFold
├── DoorLeaf (BoxMesh)           size=(OPENING*0.86, door_height*0.90, 0.045), 色=base_color.darkened(0.12)
└── DoorCue (BoxMesh)            size=(0.045,0.045,0.035), 色=Color("f1c24b")
```
- `door_height = WALL_HEIGHT * 0.72`；`side_width = (span - CARDBOARD_DOOR_OPENING) * 0.5`；
  `header_height = WALL_HEIGHT - door_height`

### 2.4 转角柱 = 纸板支撑脚（替代 kaykit_wall_corner / pillar）

```
CardboardJunction (Node3D)
├── Post (BoxMesh)      size=(JUNCTION_WIDTH, height, JUNCTION_WIDTH), 色=base_color.darkened(0.10)
├── PostCap (BoxMesh)   size=(JUNCTION_WIDTH+0.035, 0.05, JUNCTION_WIDTH+0.035), 色=base_color.lightened(0.10)
└── TapeBand (BoxMesh)  size=(JUNCTION_WIDTH+0.012, 0.045, JUNCTION_WIDTH+0.012), 色=Color("e5d49d")
```
- `height = WALL_HEIGHT`（转角与墙同高）；位置在两条垂直墙的交点

### 2.5 地板 = 纸板底盘（替代 kaykit_foor_wood）

房间底板仍用 v2 的 CSGBox 纸盒白 `#f4ede0`（这部分 v2 是对的，保留）。
但**地板贴面**（如可选）用纸板色 `#f4ede0` + 轻微折痕色，不再用 KayKit 木地板 gltf。
可选，不强制；房型单一背景时不做木地板。

### 2.6 资产目录 `asset_catalog.json` 的墙条目处理

`structure` 分类里 `kaykit_wall*`、`kaykit_pillar`、`kaykit_floor*`、`kaykit_stairs`
这些**砖墙/木地板相关条目从面板里移除或标记为"不可用"**——因为它们不再代表正式片场墙体。
两种做法（Codex 二选一，推荐 A）：
- **A**：从 `asset_catalog.json` 删除这些 `kaykit_wall*`/`kaykit_pillar`/`kaykit_floor*`/`kaykit_stairs`
  条目，`structure` 分类只保留地图/装饰层（如无则整类留空）。墙/门/转角改由**墙工具**走纸板件生成，
  不再作为普通资产摆放。
- **B**：保留条目但 `category` 改为 `"_disabled"`，面板过滤掉 `_disabled`。（改动最小）

> **重要**：墙工具（`WALL_TOOL_IDS`）的 4 个 id `kaykit_wall / kaykit_wall_half /
> kaykit_wall_doorway / kaykit_wall_shelves` 不再指资产路径，改为指**纸板件类型**：
> `cb_wall / cb_wall_half / cb_doorway / cb_shelves`。Codex 需把 `WALL_TOOL_IDS`、
> `_place_wall_segment`、`_show_wall_preview`、`_draw_wall`、`_rebuild_walls_from_snapshot`、
> `_rebuild_corners`、预设模板的 `kind` 值全部换成新 id 并映射到 §2.2–2.4 纸板件。

### 2.7 纸板件与地编系统的接缝

纸板件是 `Node3D` + 多个 `BoxMesh`（不是 gltf PackedScene），所以：
- `_instantiate_asset` 不再用于墙/转角；改为 `CardboardShellBuilder.build_wall(kind, position, yaw, color_index)` 直接生成 `Node3D`。
- 墙段的 meta 与撤销/模板序列化**不变**（仍存 `wall_kind`/`wall_axis`/`wall_cell`），数值换成新 id。
- 纸板件不参与资产 AABB 重叠检测？——墙保持参与（墙-墙不重叠），且墙 AABB 用**外包围盒**
  （span × WALL_HEIGHT × PANEL_THICKNESS，按 yaw 旋转后求世界 AABB）。
- 材质的 `roughness=0.98, metallic=0.0`（纸板哑光），阴影照常。

## 3. 美学验收线（v3 新增，可勾选、可截图验证）

这是 v2 缺的：把"好看/像片场"变成可验收项。每项都附**怎么看**与**最低标准**。

| # | 验收项 | 最低标准（截图/移动检查） |
|---|---|---|
| A1 | **墙材质是纸板** | 墙面为乳白/奶油色（base_color），有 TopFold 折边 + TapeSeam 米色胶带；**无**砖块纹理、无地牢石材 |
| A2 | **墙高可透视** | 相机默认俯角下，能透过墙顶看到房间内部家具；墙顶不遮住中心家具 | 
| A3 | **墙沿外轮廓** | 拖拽画任意长度墙，墙段全部贴房间外边界，**None** 延伸到房间内部/外部 |
| A4 | **转角收口** | 正交墙相交处有纸板支撑脚（Post+PostCap+TapeBand），无空心豁口、无重叠穿插 |
| A5 | **门洞清晰** | 门洞墙有 DoorLeaf + Header + DoorCue 金色圆点，门洞开口 0.66 格，能从门口进出逻辑格 |
| A6 | **家具主题** | 预置模板加载后，家具按房间主题摆放（厨房=冰箱/烤箱/餐桌，卧室=床/床头柜/地毯），无杂乱堆叠 |
| A7 | **手作色** | 家具表面为 felt / painted_wood / clay 色（柔粉/浅蓝灰/米黄/灰绿等），无低模地牢原色 |
| A8 | **比例真实** | 莉莉参照物旁边，家具不超身高太多（沙发/床约为莉莉身高 1.2–1.8 倍）、墙约为莉莉 2 倍高 |
| A9 | **片场道具** | 每间房至少一件节目摄影棚证据（场记板/走位胶带/提词灯/假窗/广播灯牌/信号锚）——v2 没有，v3 补 |
| A10 | **背景隔离** | 深灰背景 + 高亮底板，房间与背景一眼可分（这项 v2 已达标，保留不复测） |

### 3.1 参考对照基线（比"只拍自己"有效）

- Codex 拍验收图时，**必须**同时贴一张参考基线作对照：
  - 正式 PCG 纸板片场效果：运行 `godot` 项目，进"节目测试台 → 桌模扩建 PCG"，截图一张；
  - 或 Tiny Glade / 纸盒微缩片场参考图（任选一张，标注来源）。
- 地编工具的效果必须与基线**视觉同源**（同样纸板、同样配色、同样比例），否则视为未达标。

### 3.2 墙高调参（给 Codex 的改动授权）

v2 墙太高的根因是直接用了 PCG 墙高 1.08。地编工具里：
- 建议将地编墙体高度压到 **0.72**（约为莉莉身高的 1.9 倍，仍能透视内部）。
- 转角柱 height 同步 = 0.72；门洞 door_height = 0.72*0.72 ≈ 0.52。
- 若调参后 A2/A8 仍不达标，Codex 可继续微调（在方案常量表里改并说明理由），
  但**必须同时贴 A2 截图证明可透视**。

## 4. 文件改动清单

| 文件 | 动作 |
|---|---|
| `godot/scripts/cardboard_shell_builder.gd` | **新增**：纸板件构建类（从 pcg_diorama_stitch_lab 移植，含常量/调色板/box/wall/doorway/junction，可独立 new） |
| `godot/scripts/asset_editor_3d.gd` | **改**：墙/转角走纸板件；WALL_TOOL_IDS 换新 id；AABB 检测适配；A9 片场道具生成 |
| `godot/scripts/asset_diorama_rules.gd` | **改**：墙几何常量对齐纸板（WALL_HEIGHT=0.72 等），`wall_kind` 枚举换新 id |
| `godot/scenes/asset_editor_3d.tscn` | **改**：可加 `CardboardShell` 容器节点；帮助文案新增"纸板墙"说明 |
| `godot/data/editor/asset_catalog.json` | **改**：按 §2.6 方案 A 移除砖墙/木地板条目（56 → 约 40+） |
| `godot/data/editor/preset_templates/*.json` | **改**：3 个模板的 `walls[].kind` 换新 id；`assets[].scale` 按 0.72 调整墙邻家具比例；每模板补 1 件片场道具（A9） |
| `godot/tests/asset_editor_smoke.gd` | **改**：墙测试改为纸板件（检查生成了 PaperBoard 而非 gltf）；新增 A1/A2 的自动可测项（墙材质颜色/数量）；预设模板测试同步 |

## 5. 测试规格

### 5.1 规则/构建单测
1. `CardboardShellBuilder.build_wall("cb_wall", pos, yaw, 0)` → 返回 Node3D，含 Panel/TopFold/TapeSeam 子节点，Panel.size == (1.27, 0.72, 0.10)
2. `build_wall` 生成的根节点 `get_meta("cardboard_shell") == true`
3. `build_doorway`：含 Side_x2/Header/DoorLeaf/DoorCue；DoorLeaf.size.x ≈ 0.66*0.86
4. `build_junction`：Post 高 == 0.72；含 PostCap/TapeBand
5. 旧 kaykit 墙 id 的模板 → 新 id 映射正确（如 `kaykit_wall → cb_wall`）
6. 墙材质的 roughness==0.98 / metallic==0.0 / albedo 属于纸板调色板集合

### 5.2 场景级（保留 v2 已有，替换墙相关断言）
- 画墙：`_draw_wall(...)` 后 Walls 子节点数是纸板件、每个子含 `cardboard_shell` meta、AABB 外包围盒正确
- 模板加载：3 个预设模板加载后 walls 是纸板件、assets 数量正确、每模板含 ≥1 片场道具节点
- `_rebuild_corners`：正交相交生成 1 个纸板转角
- 墙高透视：相机默认位下，房间中心家具的屏幕位置在墙顶以上（可读墙顶 Y 与家具 Y 对比）

### 5.3 新增美学验收测试（人工截图 + 自动可选）
- A1/A3/A4/A6/A9 用截图+检查项核对（§3 表）
- A2/A8 用几何断言（墙高 0.72 vs 莉莉身高、墙顶 Y > 家具顶 Y）

## 6. Codex 执行步骤（严格按顺序）

1. 读本文件 + v2 的 5 个文件 + `pcg_diorama_stitch_lab.gd` 的纸板函数（2000–2102 行）。
2. 新建 `godot/scripts/cardboard_shell_builder.gd`（§2.1–2.4），先跑 §5.1 构建单测。
3. 改 `asset_diorama_rules.gd`：墙常量（WALL_HEIGHT=0.72、PAPER_COLOR 等）、`wall_kind` 枚举换新 id。
4. 改 `asset_editor_3d.gd`：墙/转角走纸板件、WALL_TOOL_IDS 换 id、AABB 适配、A9 片场道具生成。
5. 改 `asset_catalog.json`：按 §2.6 方案 A 移除砖墙/木地板条目。
6. 改 3 个预设模板：kind 换新 id、scale 调整、补片场道具。
7. 改 `asset_editor_3d.tscn`：加 CardboardShell 容器、帮助文案。
8. 改 `asset_editor_smoke.gd`：墙断言换纸板件，新增 §5.1/5.2。
9. headless 跑测试：`D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path G:\dream-channel\godot --script res://tests/asset_editor_smoke.gd`（如遇 headless 崩溃，先退出正在运行的 Godot GUI 实例再跑；崩溃是环境/并发问题，不是测试失败——见 v2 记录）。
10. godot-mcp 连运行 Godot，F6 运行 `asset_editor_3d.tscn`，**先拍 1 张对照基线（正式片场效果）**，再按 §3 表拍 A1–A10 验收图（至少 6 张），每张与基线比视觉同源。
11. 跑正式回归（`smoke_test`、`pcg_diorama_stitch_smoke`）确认无副作用。
12. 按项目规范提交（`feat(godot):` 前缀，只 add 改动文件，不加 `.import`/`.gd.uid`/lab_logs）。示例：`feat(godot): 地编工具 v3——纸板片场载体、墙体比例校正、片场道具、美学验收线`。
13. 报告：改动文件清单 + 测试输出 + 基线对照截图 + §3 表逐项打勾结果 + A2/A8 几何断言数字。

## 7. 验收清单（全部勾选才算完成）

- [ ] 所有墙/门/转角为**纸板件**（A1：无砖纹、无地牢石材）
- [ ] 墙高 0.72，默认相机能透视内部家具（A2）
- [ ] 拖拽墙全部贴外轮廓（A3）
- [ ] 转角有纸板支撑脚收口（A4）
- [ ] 门洞清晰、开门 0.66 格、金色 DoorCue（A5）
- [ ] 3 模板家具按主题摆放、无堆叠（A6）
- [ ] 家具手作色（A7）
- [ ] 比例真实（A8：与莉莉参照对比）
- [ ] 每房 ≥1 片场道具（A9）
- [ ] 聚焦背景隔离保留（A10）
- [ ] headless 测试通过（§5）
- [ ] 与正式 PCG 纸板片场基线**视觉同源**
- [ ] 正式游戏回归（smoke_test、pcg_diorama_stitch_smoke）未破坏
- [ ] 未改正式游戏流程脚本（channel_3d 等）；v1/v2 遗留文件原样

## 8. 禁止事项

- ❌ 不允许继续用 KayKit 砖墙 gltf 当正式墙（只可留作历史对比）
- ❌ 不允许把墙做到 1.08 高（必须按 §3.2 压到 0.72 或更低直到可透视）
- ❌ 不允许让墙延伸到房间内部/外部（必须贴外轮廓）
- ❌ 不允许引入新的第三方资产/插件
- ❌ 不允许改正式游戏流程（channel_3d.tscn、pcg_diorama_stitch_lab 的正式逻辑）
- ❌ 不允许只拍自己工具的图交差（必须与正式片场基线对照）
- ❌ 不允许改动 v1/v2 的既有功能交互语义（画墙/拆借/键位/三档/撤销）——只换载体与视觉
