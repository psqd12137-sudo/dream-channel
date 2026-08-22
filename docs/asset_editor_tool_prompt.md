# 3D 资产摆放地编工具（Asset Editor 3D）执行方案 · 给 Codex

> 状态：实施计划（2026-08-22）
> 用法：把本文件全文粘贴给 Codex，让它按「执行步骤」逐条实施。本方案已经把
> 文件路径、函数名、数据格式、交互规格和验收标准全部写死，Codex 只需要照做，
> 不需要再调研或自行发挥。
> 前置数据文件 `godot/data/editor/asset_catalog.json` 已预置在仓库中，直接使用。

## 1. 目标（一句话）

做一个 **Godot 4.7 游戏内运行的可视化 3D 资产摆放地编工具**：玩家（或开发者在
游戏运行时）从资产面板点选家具/墙体/道具，鼠标在地面上移动出现半透明预览并按
1.55m 网格吸附，左键放置，R 旋转 90°，选中后可拖动/删除，最后把整局摆放结果
导出为 JSON 布局文件，并可从 JSON 重新加载回来。

这是「**摆放资产的**」工具。核心是摆家具、摆墙、摆装饰。不是房间形状规划器，
不是格子连接检查器。

## 2. 上次做错了什么（本次绝对禁止，逐条阅读）

上一轮 Codex 交付的 `RoomBuilder3D`（`godot/scenes/room_builder_3d.tscn`）不符合需求，
原因如下。本次**禁止再犯**：

1. ❌ **没有资产摆放能力**：RoomBuilder3D 只显示纸盒占位壳体，不能放置任何真实资产。
   ✅ 本次必须能实例化真实 3D 模型资产并摆放到地面。
2. ❌ **只能改 Inspector 数字**：RoomBuilder3D 靠改 `grid_position`/`footprint_kind` 编辑，
   不是可视化地编。✅ 本次必须是鼠标所见即所得的交互。
3. ❌ **留了一个空 GridMap 占位**：声称"未来替换 MeshLibrary"，实际什么都没接。
   ✅ 本次不用 GridMap，直接用项目现有的 `load(path).instantiate()` 模式。
4. ❌ **引入 MetSys 第三方插件**（2D 房间地图编辑器），方向根本不对，已废弃。
   ✅ 本次不引入任何第三方插件/asset library。
5. ❌ **没有保存/加载**。✅ 本次必须有 JSON 导出与回读。
6. ❌ **没有测试**。✅ 本次必须带 headless 回归测试并通过。

**遗留文件处理**：`godot/scenes/room_builder_3d.tscn`、`godot/scripts/room_builder_3d.gd`、
`godot/scripts/room_builder_room.gd`、`godot/tools/room_builder_3d_README.md`、
`godot/tools/metsys/`、`godot/addons/`、`godot/scenes/metsys_pipeline_lab.tscn`、
`godot/data/pcg/metsys_room_manifest.json` 保持原样，**不修改也不删除**。本次工作完全独立。

## 3. 需求范围（最小闭环）

### 3.1 必须做（MVP，全部验收）

| # | 功能 | 说明 |
|---|---|---|
| M1 | 资产面板 | 左侧可滚动面板，按 4 个分类（家具/墙体结构/道具/装饰）分组列出所有资产，点选进入放置模式 |
| M2 | 网格吸附预览 | 选中资产后，鼠标在地面移动时显示**半透明幽灵预览**，位置吸附到 1.55m 网格 |
| M3 | 放置 | 左键点击放置资产（放置后保持同资产连续放置模式，方便连摆） |
| M4 | 旋转 | 放置前幽灵可用 R 旋转 90°；放置后选中资产按 R 旋转 90° |
| M5 | 选中/取消 | 左键点击已放置资产选中（脚下金色圆环高亮）；点击空白取消选中；Esc 退出放置模式 |
| M6 | 拖动移动 | 选中资产后左键按住拖动，按网格吸附移动 |
| M7 | 删除 | 选中后按 Delete 删除；提供"清空全部"按钮 |
| M8 | 导出 JSON | 输入布局名，导出到 `user://asset_editor_layouts/<name>.json` |
| M9 | 加载 JSON | 从 `user://asset_editor_layouts/<name>.json` 读回重建全部资产 |
| M10 | headless 回归测试 | `godot/tests/asset_editor_smoke.gd` 通过 |

### 3.2 明确不做（防止范围膨胀）

- ❌ 不接入正式游戏流程（不改 `channel_3d.tscn`、不加快捷入口到"节目测试台"，本次不做）
- ❌ 不做多房间/大地图连接、不做门缝 PCG 检查（那是另一件事）
- ❌ 不做 Undo/Redo 栈（MVP 之外）
- ❌ 不做资产缩放手势（scale 由 catalog 决定，不在运行时调）
- ❌ 不做垂直堆叠/吸附到家具顶面（只吸附地面 y=0）
- ❌ 不改任何现有脚本（`channel_3d.gd`、`pcg_diorama_stitch_lab.gd`、`room_art_registry.gd` 等一律不动）

## 4. 可复用的现有资产与常量（直接抄，不要自己发明）

| 项目 | 值 | 来源 |
|---|---|---|
| 网格尺寸 | `CELL := 1.55`（米） | `godot/scripts/pcg_diorama_stitch_lab.gd` 第 10 行 |
| 资产目录 | `godot/data/editor/asset_catalog.json`（已预置 56 条） | 本次已入库 |
| 资产实例化模式 | `load(path) as PackedScene` → `instantiate()` → 设 `scale`/`rotation.y` → `add_child` | `pcg_diorama_stitch_lab.gd::_add_model`（1933 行） |
| 阴影开启 | 实例化后遍历 `find_children("*", "MeshInstance3D", true, false)` 设 `cast_shadow = SHADOW_CASTING_SETTING_ON` | `room_art_registry.gd::_set_prop_shadows` |
| 测试风格 | `extends SceneTree`，`_init()` → `call_deferred("_run")`，`_check(cond, msg)` 收集失败，最后 `print("CHANNEL_XXX: PASS ...")` + `quit(0)` 或 `push_error` + `quit(1)` | 任意 `godot/tests/*.gd` |
| Godot 可执行文件 | `D:\godot\Godot_v4.7.1-stable_win64_console.exe`（headless 测试用）；带图形界面的是 `D:\godot\Godot_v4.7.1-stable_win64.exe` | 本机 |
| 项目根 | `G:\dream-channel\godot` | 本机 |

## 5. 文件清单（本次新增，共 3 个文件）

| 文件 | 职责 |
|---|---|
| `godot/data/editor/asset_catalog.json` | **已预置**。资产清单。Codex 不要重写它，只读取；如发现条目有误可修正单条并说明理由 |
| `godot/scripts/asset_editor_3d.gd` | 地编模式全部逻辑（新建） |
| `godot/scenes/asset_editor_3d.tscn` | 地编场景（新建，节点树见 §7） |
| `godot/tests/asset_editor_smoke.gd` | headless 回归测试（新建） |

## 6. 数据规格

### 6.1 `asset_catalog.json`（已预置，只读）

结构：`schema_version`、`cell_size`、`categories`（4 个：furniture/structure/prop/decor）、
`assets`（56 条）。每条字段：

- `id`：稳定字符串 id（导出 JSON 用它引用资产）
- `path`：`res://` 资源路径
- `category`：分类 id（对应 categories）
- `name`：中文显示名（面板按钮文字）
- `scale`：**数字**（等比例缩放）或 **`[x, y, z]` 数组**（非等比，墙体/地板用）
- `yaw_steps`：旋转档位数（本工具固定 4，即 90° 一档）
- `snap`：吸附模式，固定 `"quarter"`（网格吸附）
- `overlay`：可选布尔，true 表示贴地薄片（地毯等），放置时 y 抬升 0.005 避免 z-fighting

**Codex 必做校验**：场景启动时对 catalog 每条 `path` 执行 `load()`，失败则 `push_warning` 并在
状态栏显示"资产缺失：<id>"，但**不中断运行**（缺失条目跳过）。

### 6.2 导出布局 JSON 格式（字段全部写死）

```json
{
	"schema_version": 1,
	"cell_size": 1.55,
	"exported_at": "2026-08-22T12:00:00",
	"catalog_revision": 1,
	"placements": [
		{
			"id": "place_0001",
			"asset_id": "kk_couch",
			"cell": [3, 2],
			"position": [4.65, 0.0, 3.1],
			"yaw_quarters": 1,
			"scale": 0.28
		}
	]
}
```

字段说明（导出和加载共用）：

- `id`：`place_%04d` 自增；加载时无需保留原 id，重新按顺序生成即可
- `asset_id`：catalog 中的 `id`；加载时若 catalog 中不存在该 id，**跳过该条并警告**
- `cell`：`[x, z]` 网格坐标（int），`position = cell * CELL`（x→X 轴，z→Z 轴）
- `position`：实际世界坐标（导出时冗余保存，加载时以 `cell` 为准重建）
- `yaw_quarters`：0–3 的整数，`rotation.y = yaw_quarters * PI / 2`
- `scale`：数字或 `[x,y,z]` 数组，原样取 catalog 条目值（运行时不允许改）

保存目录：`user://asset_editor_layouts/`（目录不存在则 `DirAccess.make_dir_recursive_absolute` 创建）。

## 7. 场景节点树规格（`asset_editor_3d.tscn` 按此结构建，节点名不要改）

```text
AssetEditor3D (Node3D)                       ← 挂 asset_editor_3d.gd
├── WorldEnvironment
├── KeyLight (DirectionalLight3D)            rotation_degrees = (-55, -25, 0), energy 1.6, shadow on
├── FillLight (DirectionalLight3D)           rotation_degrees = (-35, 145, 0), energy 0.7
├── GroundMesh (MeshInstance3D)              PlaneMesh 32×32m，纸色 #e8e0c8，代码里生成网格线
├── Placements (Node3D)                      ← 所有已放置资产挂这里
├── Ghost (Node3D)                           ← 幽灵预览实例挂这里（复用，切换资产才重建）
├── SelectionRing (MeshInstance3D)           TorusMesh 半径 0.55，金色 #f3a51f 自发光，默认隐藏
├── CameraRig (Node3D)
│   └── Camera3D                             fov 50，初始 position (0, 14, 16)，等距俯视
└── UI (CanvasLayer)
    ├── Panel (PanelContainer)               左侧，offset_left=16, top=16, right=300, bottom=-16
    │   └── VBox
    │       ├── Title (Label)                "资产地编 Asset Editor"
    │       ├── CatalogScroll (ScrollContainer)   vertical expand
    │       │   └── CatalogList (VBoxContainer)   ← 代码动态生成分类标题 + 资产按钮
    │       └── Status (Label)               底部状态栏（选中/模式/导出反馈）
    ├── TopBar (HBoxContainer)               顶部，anchors top wide，代码里动态生成以下控件：
    │   ├── LoadName (LineEdit)              placeholder "布局名（导出/加载共用）"
    │   ├── ExportBtn (Button)               "导出"
    │   ├── LoadBtn (Button)                 "加载"
    │   └── ClearBtn (Button)                "清空"
    └── HelpLabel (Label)                    右下角操作提示，autowrap
```

说明：TopBar 的按钮/输入框可以在 tscn 里静态创建（推荐，节点名固定如上），
CatalogList 里的分类标题和资产按钮**必须代码动态生成**（读 catalog JSON）。

## 8. 脚本函数规格（`asset_editor_3d.gd`，按此实现）

```gdscript
extends Node3D

const CELL := 1.55
const CATALOG_PATH := "res://data/editor/asset_catalog.json"
const LAYOUT_DIR := "user://asset_editor_layouts/"

var catalog: Dictionary = {}          # {"categories": [...], "assets": [...]}
var selected_asset: String = ""       # 当前放置模式资产 id；空 = 未在放置模式
var ghost_yaw_quarters := 0
var selection: Node3D = null          # 当前选中的已放置实例
var drag_from := Vector3.ZERO
var dragging := false
var place_counter := 0
var failed_paths: Array[String] = []
```

必须实现的函数（签名和职责照抄）：

| 函数 | 职责 |
|---|---|
| `_ready()` | 读 catalog → 校验全部路径 → `_build_catalog_panel()` → 生成地面网格线 → 连接 TopBar 按钮 → `_update_help()` |
| `_build_catalog_panel()` | 遍历 categories 顺序，每组先加分类标题 Label，再为该分类每条 asset 加一个 Button（text=name，meta 存 asset_id），`pressed.connect(_on_asset_pressed.bind(asset_id))` |
| `_on_asset_pressed(asset_id)` | 进入放置模式：`selected_asset = asset_id`，重建 Ghost（实例化该资产，半透明），取消 selection |
| `_rebuild_ghost()` | free 旧 Ghost 子节点 → `load(path).instantiate()` → 设 scale → 全部材质改半透明（见 §9.2）→ 放 Ghost 下，`rotation.y = ghost_yaw_quarters * PI/2` |
| `_unhandled_input(event)` | 全部输入入口，处理顺序见 §9.1 |
| `_mouse_ground_point(event) -> Vector3` | 射线与 y=0 平面求交（见 §9.3），无交点返回 `Vector3(INF, INF, INF)` |
| `_snap(point) -> Vector3` | `Vector3(roundf(x/CELL)*CELL, 0, roundf(z/CELL)*CELL)` |
| `_update_ghost_position(mouse)` | 幽灵位置 = `_snap(交点)`；交点无效则 `Ghost.visible = false` 否则 true |
| `_place_at(cell: Vector2i, asset_id: String, yaw_quarters: int) -> Node3D` | **核心放置函数**（测试也直接调它）：查 catalog 条目 → 实例化 → scale（数字则等比例，数组则分量）→ position = cell*CELL（y 加 overlay 抬升）→ rotation.y → 挂到 Placements → 开阴影 → `set_meta("asset_id", ...)`、`set_meta("cell", ...)`、`set_meta("yaw_quarters", ...)` → 返回节点；条目缺失返回 null |
| `_pick_placement(mouse) -> Node3D` | 对 Placements 全部子节点做 AABB 点测试（见 §9.4），命中返回最近者，否则 null |
| `_select(node)` / `_deselect()` | 设 selection、SelectionRing 位置到该节点脚下、visible=true / false |
| `_rotate_selected()` | 选中则 `yaw_quarters = (yaw_quarters+1)%4` 并更新 meta 与 rotation.y；未选中但处于放置模式则旋转幽灵 |
| `_delete_selected()` | free 选中节点 + `_deselect()` |
| `_clear_all()` | free Placements 全部子节点 + 重置计数 |
| `_export_layout(name) -> String` | 组装 §6.2 格式 JSON，`DirAccess` 写盘，返回**完整 JSON 文本**（测试用文本做往返校验）；成功状态栏显示路径 |
| `_load_layout(name) -> int` | 读盘 → JSON.parse → `_clear_all()` → 逐条 `_place_at`，返回成功重建条数；缺目录/坏 JSON 时状态栏报错返回 -1 |
| `_update_status() / _update_help()` | 状态栏与操作提示文本 |

辅助：`_find_asset_entry(asset_id) -> Dictionary`、`_apply_scale(node, entry)`、
`_set_ghost_transparency(node)`、`_make_ground_grid()`（地面网格线，§9.5）。

## 9. 交互与视觉规格（照做即可，不要自由发挥）

### 9.1 输入处理顺序（`_unhandled_input` 内按此顺序判断）

| 输入 | 条件 | 行为 |
|---|---|---|
| `InputEventMouseButton` 滚轮 up/down | 任意 | 相机沿视线方向推进/拉远（`camera.position += camera_dir * delta`，clamp 距离地面 6–40m） |
| `InputEventMouseMotion` 中键按住 | 任意 | 相机 XZ 平移（移动量 × 0.01 × 相机高度比例），**不改旋转** |
| `InputEventMouseMotion` 左键按住 + `selection != null` + `dragging` | 选中拖动 | 选中节点位置 = `_snap(交点)`，同步更新 meta cell 与 SelectionRing |
| `InputEventMouseMotion` 其他 | 放置模式 | `_update_ghost_position()` |
| 鼠标左键 press | `selected_asset != ""`（放置模式） | 射线求交成功 → `_place_at(snap)` → 不退出放置模式（连续摆） |
| 鼠标左键 press | 非放置模式 | `_pick_placement()` 命中 → `_select` 并标记 dragging；未命中 → `_deselect` |
| 鼠标左键 release | `dragging` | `dragging = false` |
| 键盘 `R` | 任意 | `_rotate_selected()` |
| 键盘 `Delete` | `selection != null` | `_delete_selected()` |
| 键盘 `Escape` | 任意 | 放置模式则退出放置（selected_asset=""，Ghost 隐藏，更新状态）；否则取消选中 |

优先级铁律：**鼠标在 UI 控件上时，3D 交互一律不响应**。用 `event.position` 先做
UI 命中检查（`get_viewport().gui_get_hovered_control() != null` 则直接 return）。

### 9.2 幽灵半透明

对 Ghost 下所有 `MeshInstance3D`：`get_surface_override_material(i)`（或 mesh 自带材质）
→ duplicate 为 `StandardMaterial3D` → `transparency = TRANSPARENCY_ALPHA` →
`albedo_color.a = 0.45` → `set_surface_override_material(i, mat)`。
幽灵不参与拾取（§9.4 只测 Placements），不投阴影（cast_shadow = OFF）。

### 9.3 射线求交（地面 y=0）

```gdscript
var origin := camera.project_ray_origin(mouse_pos)
var direction := camera.project_ray_normal(mouse_pos)
if absf(direction.y) < 0.0001:
    return Vector3(INF, INF, INF)   # 平行于地面
var t := -origin.y / direction.y
if t < 0.0:
    return Vector3(INF, INF, INF)   # 交点在相机后方
return origin + direction * t
```

### 9.4 拾取（点到资产 AABB）

对 Placements 每个子节点：取第一个 `MeshInstance3D` 的 `get_aabb()`（global 变换后），
做射线与 AABB 相交测试（Godot 无内置单测，用 slab 方法自己写，约 20 行）；命中多个
取 t 最小。**不要**用 `PhysicsRayQuery`（GroundMesh 不加碰撞体，资产不加 StaticBody），
纯几何拾取即可，避免物理层干扰。

### 9.5 地面网格线

`GroundMesh` 是 PlaneMesh 只做底色。另外用 `ImmediateMesh` 画 32×32m 范围、
间距 CELL 的线条（`surface_begin(Mesh.PRIMITIVE_LINES)`），颜色 `#00000022`，
挂在 GroundMesh 下作为子节点。这是吸附可视化的关键，必须有。

### 9.6 相机

透视 Camera3D，固定等距俯视角（rotation 初始即场景里的值，运行期**只有平移和
沿视线推进**，不给自由旋转——MVP 简单稳定）。初始 `look_at(Vector3.ZERO)`。

## 10. 测试规格（`asset_editor_smoke.gd`，extends SceneTree）

按项目现有测试风格写。用例清单（每条失败都要 `_check` 记录）：

1. **catalog 可加载**：`FileAccess.open(CATALOG_PATH)` 成功、JSON 解析后 `assets` 非空、分类数 == 4。
2. **catalog 路径全有效**：场景 `_ready` 后 `failed_paths.is_empty()`（缺资产会在状态收集器里）。
3. **场景实例化**：`(load("res://scenes/asset_editor_3d.tscn") as PackedScene).instantiate()` 非空，add 到 root 后 await 两帧。
4. **面板构建**：CatalogList 子节点数 == 4 个分类标题 + 56 个资产按钮（或按实际 catalog 条目数动态断言）。
5. **放置**：调 `editor._place_at(Vector2i(2,1), "kk_couch", 0)` → 返回非空、Placements 子节点数 1、节点 position == (2*1.55, 0, 1*1.55)、meta 正确。
6. **旋转**：对同一节点调 `_rotate_selected()`（先 `_select(node)`）→ `yaw_quarters == 1`、`rotation.y ≈ PI/2`。
7. **删除**：`_delete_selected()` → Placements 子节点数 0。
8. **导出往返**：放 3 个不同资产 → `_export_layout("__smoke")` 返回文本 → JSON.parse 后 `placements.size() == 3`、字段齐全 → `_clear_all()` → `_load_layout("__smoke")` == 3 → Placements 子节点数 3、坐标与 cell 重建一致。测试结束删除 `user://asset_editor_layouts/__smoke.json`（若受限环境写不了 user://，把"写盘+读盘"改为只用导出文本 parse 校验并打印 `CHANNEL_ASSET_EDITOR: NOTE user:// write unavailable (sandbox)`，不判失败——参考 README 自检节说明）。
9. **缺资产跳过**：`_place_at(Vector2i.ZERO, "not_exist", 0)` 返回 null 且不产生子节点。

收尾：全部通过 `print("CHANNEL_ASSET_EDITOR: PASS ...")` + `quit(0)`；失败逐条 `push_error` + `quit(1)`。

## 11. Codex 执行步骤（严格按顺序）

1. 读本文件 + `godot/data/editor/asset_catalog.json`，确认 56 条资产 `path` 与磁盘文件一一对应（可用 `Test-Path` 或 Godot `ResourceLoader.exists` 抽查）。
2. 新建 `godot/scripts/asset_editor_3d.gd`，按 §8 实现。
3. 新建 `godot/scenes/asset_editor_3d.tscn`，按 §7 节点树搭建（脚本挂根节点，UI 节点名照抄）。
4. 新建 `godot/tests/asset_editor_smoke.gd`，按 §10 实现。
5. headless 跑测试：
   `D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path G:\dream-channel\godot --script res://tests/asset_editor_smoke.gd`
   直到输出 `CHANNEL_ASSET_EDITOR: PASS`。
6. 用 godot-mcp 连接运行中的 Godot，打开 `asset_editor_3d.tscn` 按 F6 运行，截图自查：
   - 面板 4 分类 56 按钮完整显示；
   - 点"沙发（带枕）"后移动鼠标出现半透明预览且吸附网格；
   - 左键摆 3 件不同家具、R 旋转一件、选中高亮圆环可见、Delete 删除一件；
   - 导出 `demo` → 清空 → 加载 `demo` → 三件恢复（删一件后剩两件则验证两件）。
7. 按项目规范提交（前缀 `feat(godot):`，只 add 本次 3 个新文件；**不要** add 任何 `.import` 缓存、`lab_logs`、`.godot/`）。提交信息示例：
   `feat(godot): 3D 资产摆放地编工具——资产面板、网格吸附放置、旋转/拖动/删除、JSON 导出回读`
8. 报告交付清单：3 个文件路径 + 测试输出 + 截图路径 + 手动验收结果。

## 12. 验收清单（全部勾选才算完成）

- [ ] `asset_editor_smoke.gd` headless 通过（`CHANNEL_ASSET_EDITOR: PASS`）
- [ ] F6 运行 `asset_editor_3d.tscn` 不报错，面板可见，可连续摆放资产
- [ ] 幽灵预览半透明、网格吸附正确（任意放置点坐标都是 1.55 的整数倍）
- [ ] R 旋转（幽灵与已放置均生效）、Delete 删除、清空按钮可用
- [ ] 拖动已放置资产移动并按网格吸附
- [ ] 导出 `demo` 后 `user://asset_editor_layouts/demo.json` 存在且格式符合 §6.2
- [ ] 清空后加载 `demo` 完整恢复
- [ ] 既有正式游戏回归未被破坏（至少跑 `smoke_test`、`pcg_diorama_stitch_smoke` 确认无副作用）
- [ ] 未改动 §2 列出的遗留文件与任何现有脚本
