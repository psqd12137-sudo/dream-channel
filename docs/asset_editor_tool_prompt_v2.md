# 3D 资产地编工具 v2（微缩景观房间编辑器）执行方案 · 给 Codex

> 状态：实施计划（2026-08-22，含用户最新反馈修订）
> 用法：把本文件全文粘贴给 Codex，让它按「执行步骤」逐条实施。
> 前置：v1 已交付并在仓库中（`godot/scripts/asset_editor_3d.gd`、`godot/scenes/asset_editor_3d.tscn`、
> `godot/tests/asset_editor_smoke.gd`、`godot/data/editor/asset_catalog.json`，另有 v1 方案
> `docs/asset_editor_tool_prompt.md`）。本方案是**在 v1 基础上的升级改造**，不是重写。
> Codex 动手前必须先读 v1 的 4 个文件，理解现状再改。

## 1. 目标（一句话）

把 v1 的"逐格放置资产"升级为**微缩景观房间编辑器**：选定一个房间形状（1/3/5 格，复用
`RoomFootprintCatalog.SHAPES`），在该房间轮廓内**连续自由摆放**资产（位置连续、角度连续、
三档大小），支持**拖拽画墙**与**模板带墙可拆借**，带 Unity 快捷键套件、平滑环绕相机、
莉莉角色比例参照物、撤销/重做、重叠检测，并把整间房的布景（含墙）保存为**房间模板 JSON**
（模板库），供以后正式 PCG 房间生成复用。

## 2. v1 现状盘点（改之前先读这些，以磁盘文件为准）

| 文件 | 现状 |
|---|---|
| `godot/scripts/asset_editor_3d.gd`（580 行） | 资产面板、幽灵预览、1.55m 整格吸附、90° 四档旋转、选中/拖动/删除、布局 JSON 导出回读 |
| `godot/scenes/asset_editor_3d.tscn` | 节点树：AssetEditor3D / WorldEnvironment / KeyLight / FillLight / GroundMesh / Placements / Ghost / SelectionRing / CameraRig / UI（Panel+CatalogScroll+TopBar+HelpLabel） |
| `godot/tests/asset_editor_smoke.gd` | headless 回归：catalog 校验、面板、放置、旋转、删除、导出往返、缺资产容错 |
| `godot/data/editor/asset_catalog.json` | 56 资产 4 分类，**本次不动**（但墙体结构类资产改为墙工具专用，见 §6.2） |

v1 的局限（本次要解决的）：
1. 所有资产吸附到 1.55m 格中心 → 一格只能放一件，做不了微缩景观
2. 旋转只有 90° 四档 → 无法斜放
3. 相机固定等距视角，只平移+缩放 → 不跟手
4. 无缩放控制 → 资产大小锁死
5. 无撤销、无重叠检测 → 摆错只能删，穿插无感知
6. 只有整局布局导出 → 没有"房间模板"概念
7. 没有墙壁系统 → 房间没有围合感
8. 没有角色参照 → 看不出资产相对角色的真实比例
9. 快捷键不符合 Unity 习惯 → 人机工效差
10. 地面灰底 + 纸盒底板视觉同阶 → 模板与背景分不清

## 3. 需求决策（用户已拍板，照此实现，不要擅自改）

| # | 决策 |
|---|---|
| D1 | 摆放位置：**默认完全自由连续**（无吸附）；**按住 Ctrl 时吸附到 0.155m 细网格**（= CELL/10） |
| D2 | 旋转：**自由任意角度**（Unity E 工具拖动旋转）；缩放：**三档固定大小 0.6 / 1.0 / 1.5**（R 键循环），不做连续缩放 |
| D3 | 编辑单位是**房间**（1 格或 3/5 格）：**单格房模板内资产限制在格边界内**；**多格房内资产可在整个房间轮廓内自由摆放（跨内部格线不受限）**，统一规则=约束作用于房间外轮廓 |
| D4 | **墙壁系统**：拖拽画墙（Tiny Glade 式）+ 模板自带墙布局可拆可拖（选中墙段拖动/删除/复制）+ 墙沿格边界 90° 吸附 |
| D5 | 相机：**右键拖动环绕旋转 + 中键平移 + 滚轮缩放，全部带平滑插值**；**F 键聚焦**选中资产/房间中心 |
| D6 | **撤销/重做栈 + 资产重叠检测**（重叠禁止放置） |
| D7 | **莉莉角色参照物**：固定站在房间外一角，可显隐，不参与碰撞/重叠/拾取 |
| D8 | **聚焦房间模式**：背景地面明显暗化淡化、房间底板高亮 + 投影感，一眼区分房间与背景 |
| D9 | **Unity 快捷键套件**（§6.1 完整表） |
| D10 | 输出：**房间模板库**（含墙布局的 JSON），**预置 3 个带墙初始模板**，取代 v1 的整局布局导出 |

## 4. 文件改动清单

| 文件 | 动作 |
|---|---|
| `godot/scripts/asset_diorama_rules.gd` | **新增**：纯规则模块（RefCounted，无场景依赖，可 headless 单测）：吸附、边界约束、重叠检测、墙壁几何、模板序列化 |
| `godot/scripts/asset_editor_3d.gd` | **改造**：接入规则模块、自由摆放/旋转/三档大小/画墙交互、平滑环绕相机、Unity 快捷键、撤销栈、参照物、聚焦房间、模板库 |
| `godot/scenes/asset_editor_3d.tscn` | **改造**：TopBar 增加房间形状选择器、旋转房间、墙工具、模板区、参照物开关；HelpLabel 文案更新 |
| `godot/data/editor/preset_templates/` | **新增目录**：3 个预置带墙模板 JSON（§8.4） |
| `godot/tests/asset_editor_smoke.gd` | **改造**：保留 v1 用例中仍成立的，新增规则单测与场景级用例（§10） |

不动：`asset_catalog.json`、所有正式游戏脚本/场景、v1 遗留的 RoomBuilder3D/MetSys 文件。

## 5. 规则模块规格（`asset_diorama_rules.gd`，全部 static func）

```gdscript
class_name AssetDioramaRules
extends RefCounted

const CELL := 1.55
const FINE_SNAP := CELL / 10.0          # 0.155，Ctrl 吸附
const SIZE_TIERS := [0.6, 1.0, 1.5]     # D2 三档
const BOUNDARY_EPSILON := 0.001
const WALL_Y_OFFSET := 0.02             # 墙段贴地微抬
```

必须实现的 static 函数（签名照抄，逻辑说明如下）：

| 函数 | 规格 |
|---|---|
| `snap_free(point: Vector3) -> Vector3` | 返回原样（自由模式），y 归 0 |
| `snap_fine(point: Vector3) -> Vector3` | X/Z 吸附到 FINE_SNAP 的最近倍数，y 归 0 |
| `rotated_cells(shape_id: String, rotation_quarters: int) -> Array[Vector2i]` | 读 `RoomFootprintCatalog.SHAPES`，按 `(x,y)→(-y,x)` 旋转 N 次 |
| `room_center_world(cells: Array[Vector2i]) -> Vector3` | 房间包围盒中心世界坐标（y=0） |
| `point_in_room(point: Vector3, cells: Array[Vector2i]) -> bool` | 点（XZ）落在任一格矩形内（含边界，容差 BOUNDARY_EPSILON）。格范围 = `[cell*CELL, cell*CELL+CELL]²` |
| `aabb_in_room(aabb: AABB, cells: Array[Vector2i]) -> bool` | AABB 在 XZ 平面的投影矩形**完全**落在房间轮廓内；用四个角点 + 中心点共 5 个采样点全部 `point_in_room` 判定（并集轮廓下该近似足够，写进注释） |
| `aabb_overlaps_xz(a: AABB, b: AABB) -> bool` | XZ 投影相交判定（y 忽略：地面摆放只有一层） |
| `wall_axis_from_drag(start: Vector3, end: Vector3) -> Vector3i` | 拖拽画墙方向判定：`abs(dx)>=abs(dz)` 返回 `Vector3i(1,0,0)`（水平），否则 `(0,0,1)`（垂直） |
| `wall_cells_from_drag(start: Vector3, end: Vector3, axis: Vector3i) -> Array[Vector3]` | 把起止点吸附到格边界（§6.2），返回该段墙上每一格边界的**世界坐标中点列表**（每段墙长 1.55m 一格，一次拖拽生成多段） |
| `wall_position_in_room(pos: Vector3, cells: Array[Vector2i]) -> bool` | 墙段位置是否在房间外轮廓**边界**上（离某条外边界线距离 < 0.02）。墙必须沿外轮廓摆，不允许在房间内部凭空画墙 |
| `make_template_json(shape_id, rotation_quarters, assets: Array[Dictionary], walls: Array[Dictionary], template_name) -> Dictionary` | 组装 §8 模板结构 |
| `parse_template_json(text: String) -> Dictionary` | 解析并校验，返回 `{"ok": true, "data": {...}}` 或 `{"ok": false, "error": "..."}` |
| `next_size_tier(current: int) -> int` | 三档循环索引 `(i+1) % 3` |

**注意**：规则模块不 import 场景；`make_template_json` 的 assets/walls 参数是**描述字典列表**
（不是 Node3D），测试可直接构造，保证可单测。

## 6. 交互规格（v2 完整输入表）

前置铁律（继承 v1）：鼠标在 UI 控件上时 3D 交互一律不响应
（`get_viewport().gui_get_hovered_control() != null` → return）。

### 6.1 Unity 快捷键套件（D9，完整表，照抄）

| 键 | 行为 |
|---|---|
| 右键按住拖动 | 环绕相机（yaw/pitch） |
| 中键按住拖动 | 平移相机（XZ 平面） |
| 滚轮 | 缩放相机（无悬停资产时） |
| **F** | 聚焦：有选中资产 → orbit_center 移到该资产位置；无选中 → orbit_center 回房间中心 |
| **W** | 移动工具键（显式）：按住 W + 左键拖动 = 移动选中/幽灵（与默认左键拖动一致，W 键是 Unity 语义保留） |
| **E** | 旋转工具键：**按住 E + 左键拖动 = 旋转选中/幽灵**（鼠标水平位移映射 yaw：`yaw -= relative.x * 0.01`），任意角度 |
| **R** | 大小档循环：选中资产或幽灵在 0.6 → 1.0 → 1.5 间切换（scale = catalog 基准 × tier） |
| **Ctrl+D** | 复制选中资产（新资产偏移 (0.5, 0, 0.5)，重叠检测拒绝则尝试反向偏移） |
| **Ctrl+Z** | 撤销 |
| **Ctrl+Y**（或 Ctrl+Shift+Z） | 重做 |
| **Delete** | 删除选中 |
| **Esc** | 退出放置模式 / 退出画墙模式 / 取消选中（逐层退出） |
| **Ctrl+拖动**（移动中） | 移动吸附 0.155m 细网格 |
| **Q** | （v1 的 Q 旋转 15° 移除，Q 不再绑定，避免与 Unity 语义冲突） |

E 旋转实现注意：`_unhandled_input` 里维护 `e_held: bool`（E 键 press/release 状态），
左键拖动时 `if e_held: rotate else: move`。旋转用鼠标**水平相对位移**驱动，松手即停止。

### 6.2 墙壁系统（D4）

**墙工具模式**（与资产放置模式互斥）：

- 面板"墙体结构"分类下的 4 个墙资产（kaykit_wall 直墙 / kaykit_wall_half 半墙 /
  kaykit_wall_doorway 门洞 / kaykit_wall_shelves 壁架）点选后**进入画墙模式**（不是普通放置）。
- 画墙：**按住左键从 A 拖到 B，松手生成墙段**。拖动过程中：
  - 起点 A 吸附到最近的房间外轮廓边界线（含格角点）；
  - 终点 B 实时吸附到同一方向轴上的最近格边界；
  - 方向由 `wall_axis_from_drag` 判定（水平/垂直），墙沿格边界 90° 吸附；
  - 预览用幽灵墙（半透明 kaykit_wall，长度 = 拖过的格数）。
- 松手后：在 A→B 覆盖的**每一格边界**生成一段墙（每段 1.55m 长，yaw 0 或 90°），
  一次入撤销栈（视为一个操作）。
- 墙角自动收口：墙段两端若与垂直方向已有墙段相接，自动在交点放 `kaykit_wall_corner`
  转角柱（y=0，旋转适配）；该转角柱是**装饰性自动生成物**，跟随两段墙存在，
  墙删除时重新计算收口。实现为 `_rebuild_corners()`，每次墙增删后调用。
- 墙段与普通资产同等待遇：可选中、可拖动（**沿其所在边界轴滑动**，吸附格边界）、
  可 Delete 删除、可 Ctrl+D 复制、可撤销。
- 墙段重叠检测：同一边界段上已有墙则拒绝放置（红色幽灵墙）。
- 门洞墙 `kaykit_wall_doorway` 同规则，只是资产不同。
- 墙段数据模型：`walls` 与 `placements` 分开存储（场景中两个容器节点 `Placements` 与 `Walls`），
  墙段 meta 含 `wall_axis`（Vector3i）、`wall_cell`（所在边界格）、`wall_kind`（资产 id）。

**模板拆借**（D4 第二部分）：加载模板时墙段全部重建；墙段可单独选中拖动/删除/复制，
即"从模板里借出来一块"。

### 6.3 相机（D5）

- 相机状态：`cam_yaw_target / cam_pitch_target / cam_distance_target` + 环绕中心 `orbit_center`
  （初始 = 房间中心，切换房间时重设）。
- `_process` 每帧指数平滑：`current = lerp(current, target, 1.0 - exp(-delta * 8.0))`，
  再由球坐标重建相机位置：`position = orbit_center + distance * (cos(pitch)*cos(yaw), sin(pitch), cos(pitch)*sin(yaw))`，`look_at(orbit_center)`。
- 右键按住拖动：`yaw -= relative.x * 0.008`，`pitch += relative.y * 0.008`；pitch clamp `[0.12, 1.45]` 弧度。
- 中键按住拖动：沿相机右/前方向（投影 XZ）平移 `orbit_center`，平移量 `0.01 * distance * relative`（y 丢弃）。
- 滚轮（无悬停资产）：`distance *= exp(step * 0.12)`，clamp `[6, 40]`。
- F 键：按 6.1 表聚焦（orbit_center 平滑移动，不瞬移）。
- 初始化：`_ready` 把 current 直接设为目标值，避免开场飞行。

### 6.4 放置（D1、D3、D6）

- 放置模式下幽灵跟随鼠标：`ghost.position = snap_free(mouse_ground_point)`；Ctrl 按住时 `snap_fine`。**连续量，不再整格吸附**。
- 边界约束：幽灵 AABB 调 `aabb_in_room`；越界 → 红色幽灵（§6.6）→ 左键放置被拒。
- 重叠检测：幽灵 AABB 与 Placements + Walls 中每个已有资产 AABB 做 `aabb_overlaps_xz`；
  重叠 → 红色幽灵 → 拒绝；`overlay=true` 资产（地毯等）豁免。
- 检测节流：motion 每 0.05s 或鼠标位移超 0.05m 才重算（注释说明）。
- 左键点击放置（连续放置模式保持）。

### 6.5 旋转与大小档（D2）

- 旋转：幽灵或选中资产，**按住 E + 左键水平拖动**任意角度；`R` 键大小档循环
  `SIZE_TIERS = [0.6, 1.0, 1.5]`（scale = catalog 基准 scale × tier，数组 scale 逐分量乘）。
- 幽灵大小档独立变量 `ghost_size_tier`，放置时固化到实例 meta。
- 角度/档位变化后重检边界与重叠（红色反馈同 §6.6）。
- **无连续缩放**：滚轮不再缩放资产（D2 三档制）。

### 6.6 选中/拖动/删除/复制

- 左键点选（`_pick_placement`，Placements 与 Walls 都参与）、左键按住拖动（W 或默认；
  拖动时位置走 `snap_free`/Ctrl `snap_fine`；墙段拖动沿其 wall_axis 轴投影吸附边界）、
  Delete 删除、Ctrl+D 复制、Esc 取消。
- 拖动落位与放置共用边界+重叠判定：`_placement_valid(target_aabb, is_overlay) -> Dictionary`
  （返回 `{"ok": bool, "reason": "out_of_bounds"|"overlap"|""}`）。
- 非法可视化：幽灵/选中资产红色 tint（对 MeshInstance3D surface override 材质 albedo 向
  `#d63b72` lerp 0.55），SelectionRing 金 `#f3a51f` ↔ 红切换。

### 6.7 撤销/重做（D6）

- 快照式：`undo_stack: Array[Dictionary]`（每项 = 完整场景快照 `{"assets": [...], "walls": [...]}`，
  深拷贝），`redo_stack` 同型。容量 50（超限丢最旧）。
- 每次会改变场景的操作**前**（放置、删除、清空、拖动落位、旋转结束、大小档切换、复制、
  画墙、拆墙、加载模板）把当前快照 push 到 undo_stack 并清空 redo_stack。拖动/旋转**过程中**不入栈。
- Ctrl+Z / Ctrl+Y 按 6.1 表。
- 快照/重建：`_snapshot_state() -> Dictionary`、`_rebuild_from_state(state)`。资产描述项：
  `{"asset_id", "position": [x,y,z], "yaw": float, "scale": [x,y,z]}`；墙描述项：
  `{"wall_kind", "position": [x,y,z], "yaw": float, "wall_axis": [i,j,k], "wall_cell": [x,z]}`。
- 资产规模几十件，快照深拷贝成本可忽略（注释说明取舍）。

### 6.8 房间画布（D3、D8）

- TopBar：`RoomShape`（OptionButton，8 项 single/line3/l3/plus5/t5/p5/stair5/u5，中文显示）+
  `RotateRoom`（房间整体旋转 90°，0–3 循环）。
- 选择/旋转房间后：重建底板、重设 orbit_center、清空 Placements+Walls（push 撤销快照）、
  状态栏显示形状名。
- 房间锚点在世界原点；cells 按 §5 `rotated_cells` 计算（可能含负坐标）。

**聚焦房间模式（D8）**：
- 背景地面：`GroundMesh` 平面材质 albedo 从浅纸色改为**深灰** `#2a2e36`；网格主线
  `#ffffff10`、细线 `#ffffff08`（暗底白线，仅作坐标参考，不抢视觉）。
- 房间底板（`RoomBase`，程序化重建）：
  - 每 cell 一个 `CSGBox3D`（CELL×0.32×CELL，亮纸盒白 `#f4ede0`，顶部 y=0.16）；
  - 外轮廓描边：外沿边放细长 CSGBox（宽 0.04、高 0.34、金 `#f3a51f`）；
  - 底板下加一层**投影 quad**：比房间外轮廓略大 0.15m 的半透明黑色平面（y=0.005，
    颜色 `#00000050`），营造"房间浮在背景上"的层次；
  - 房间中心 `Label3D`（"3格 L 形房"，billboard，字号 0.5，墨色）。
- 效果验收标准：一眼能看出哪里是房间、哪里是背景；截图自查时对比明显。

### 6.9 角色参照物（D7）

- `ReferenceActor` 节点：加载**莉莉正式模型**——从 `godot/data/presentation_manifest.json`
  读玩家条目 `model_path` 与 `model_scale` 实例化（与正式游戏同款同比例）。
- 位置：房间外轮廓 AABB 的**右下角外侧** 1.2 格处（`room_aabb_max + Vector3(1.2*CELL, 0, -0.3*CELL)`，
  大致朝房间方向，yaw 面向房间中心）。
- 顶部小 `Label3D`（"比例参照 · 莉莉"，billboard）。
- 不参与：拾取、重叠检测、边界约束、撤销栈、模板导出。
- TopBar 增加 `ToggleActor` 按钮（"参照物：显示/隐藏"），默认显示；切换房间时重新摆位。
- 模型加载失败：回退为一个 0.9m 高的简单胶囊（MeshInstance3D CapsuleMesh + 灰色材质），
  并 `push_warning`，不阻塞运行。

### 6.10 模板库（D10）

- 模板目录：`user://diorama_templates/`（用户自存）+ `res://data/editor/preset_templates/`
  （预置只读，随仓库入库）。模板列表 = 预置 + 用户目录合并（预置标"内置"）。
- 保存：`_save_template(name)` → 快照 → `make_template_json` → 写 `user://diorama_templates/<name>.json`。
- 加载：`_load_template(name)` → parse → 设置 RoomShape/RotateRoom → 重建底板/参照物 →
  `_rebuild_from_state` → 撤销栈入快照。
- 删除：只能删除用户目录的模板；预置模板删除按钮置灰。
- **v1 的整局布局导出/加载移除**（`user://asset_editor_layouts/` 不再使用）。

## 7. 场景节点树（tscn 改造，节点名固定）

```text
AssetEditor3D (Node3D)
├── WorldEnvironment
├── KeyLight (DirectionalLight3D)            rotation_degrees = (-55, -25, 0), energy 1.6, shadow on
├── FillLight (DirectionalLight3D)           rotation_degrees = (-35, 145, 0), energy 0.7
├── GroundMesh (MeshInstance3D)              32×32m 平面，深灰 #2a2e36 + 双层网格线（子节点 GridLines）
├── RoomBase (Node3D)                        ← 房间底板/描边/投影/标签（程序化重建，本次新增）
├── Placements (Node3D)                      家具道具实例
├── Walls (Node3D)                           ← 墙段实例（本次新增，与 Placements 分开）
├── Corners (Node3D)                         ← 自动转角柱（本次新增，_rebuild_corners 管理）
├── Ghost (Node3D)                           幽灵预览（资产或墙共用）
├── SelectionRing (MeshInstance3D)           TorusMesh 半径 0.55，金/红切换
├── ReferenceActor (Node3D)                  ← 莉莉参照物（本次新增）
├── CameraRig (Node3D)
│   └── Camera3D                             fov 50，初始 position (0, 14, 16)
└── UI (CanvasLayer)
    ├── Panel (PanelContainer)               左侧资产面板（同 v1）
    │   └── VBox
    │       ├── Title (Label)                "资产地编 Asset Editor"
    │       ├── CatalogScroll (ScrollContainer)
    │       │   └── CatalogList (VBoxContainer)
    │       └── Status (Label)
    ├── TopBar (HBoxContainer)               顶部（改造）：
    │   ├── RoomShapeLabel (Label)           "房间："
    │   ├── RoomShape (OptionButton)         8 形状（中文名）
    │   ├── RotateRoom (Button)              "旋转房间 90°"
    │   ├── Sep1 (VSeparator)
    │   ├── ToggleActor (Button)             "参照物：显示"
    │   ├── Sep2 (VSeparator)
    │   ├── TemplateName (LineEdit)          placeholder "模板名（如 kitchen_01）"
    │   ├── TemplateSave (Button)            "保存模板"
    │   ├── TemplateLoad (Button)            "加载模板"
    │   ├── TemplateList (OptionButton)      模板列表
    │   ├── TemplateRefresh (Button)         "刷新"
    │   ├── TemplateDelete (Button)          "删除"
    │   ├── ClearBtn (Button)                "清空"
    └── HelpLabel (Label)                    右下角，文案见下
```

HelpLabel 文案（照抄）：
```
左键：放置/选中/拖动   E+拖动：旋转   R：大小档(0.6/1.0/1.5)   Ctrl+D：复制
右键拖动：环绕   中键拖动：平移   滚轮：缩放相机   F：聚焦
Ctrl+拖动：吸附细网格   Delete：删除   Ctrl+Z/Y：撤销/重做   Esc：取消
墙工具（墙体结构分类）：左键从 A 拖到 B 画墙，松手生成；墙段可选中拖动/删除
```

## 8. 数据格式

### 8.1 模板 JSON（schema v2，字段写死）

```json
{
	"schema_version": 2,
	"template_name": "kitchen_01",
	"room_shape": "l3",
	"room_rotation_quarters": 0,
	"saved_at": "2026-08-22T18:00:00",
	"assets": [
		{"id": "q_oven", "position": [0.42, 0.0, 0.15], "yaw": 2.35, "scale": [0.27, 0.27, 0.27]}
	],
	"walls": [
		{"kind": "kaykit_wall", "position": [0.775, 0.02, 0.0], "yaw": 1.5708, "axis": [0, 0, 1], "cell": [0, 0]}
	]
}
```

- `assets[].scale`：三轴实际值（含档位换算后），加载直接应用。
- `walls[].position`：墙段世界坐标（房间坐标系）；`yaw` 弧度（0 或 π/2）；`axis`/`cell` 冗余
  记录（用于拖动轴约束与角收口重建）。
- 解析容错：`schema_version != 2` 或字段缺失 → `parse_template_json` 返回 `ok=false`。

### 8.2 预置模板（§8.4 要求 Codex 生成）

三个内置模板，每个都必须带**完整外轮廓墙布局**（含至少一个门洞）与 3–6 件主题家具。
家具用 catalog 已有资产，坐标/角度 Codex 自行设计但要合理（贴墙家具沿墙放、不压边界、
墙内缩 0.3–0.5 格）。模板设计参考正式玩法房间主题（`RoomPropCatalog.THEME_ALIASES`）。

| 文件名 | room_shape | 主题 | 墙布局 | 家具（示例，Codex 可微调） |
|---|---|---|---|---|
| `preset_kitchen_01.json` | `single`（1 格） | 厨房 | 四边直墙，南边 1 个门洞 | 冰箱、烤箱贴北墙，中桌+木凳×2 |
| `preset_bedroom_l3_01.json` | `line3`（3 格长条） | 卧室 | 外轮廓直墙，东端门洞 | 双人床贴墙、床头柜、地毯、落地灯、相框 |
| `preset_hall_t5_01.json` | `t5`（5 格 T 形） | 大厅 | 外轮廓直墙+两处门洞+壁架墙一段 | 沙发组+矮桌、书架×2、壁炉、盆栽、地毯 |

预置模板生成方式：Codex 手工撰写 JSON（按 §8.1 格式，墙位置精确到格边界坐标），
不必在 Godot 里摆。写完后用 §10 测试验证可加载。

## 9. 视觉验收快照要求（godot-mcp 截图，至少 6 张）

1. 聚焦房间模式：深灰背景 + 亮白底板 + 金描边 + 投影 quad + 房间标签，层次分明
2. 莉莉参照物站在房间右下角外侧，比例直观
3. 拖拽画墙中：半透明幽灵墙吸附格边界
4. 画墙完成：多段墙 + 自动转角柱收口
5. 自由摆放 + 斜放 + 三档大小对比（同一资产 0.6/1.0/1.5 并排）
6. 越界/重叠红色幽灵
7. 预置模板加载效果（hall_t5 全景）

## 10. 测试规格（改造 `asset_editor_smoke.gd`）

### 10.1 保留并适配的 v1 用例

catalog 加载/路径校验/面板构建、基本放置（改自由坐标参数）、选中/删除、缺资产容错。
v1"布局导出往返"用例删除（功能移除）。

### 10.2 规则单测（不实例化场景）

1. `snap_fine((0.333,0,0.4))` → `(0.31, 0, 0.465)`
2. `rotated_cells("l3", 1)` → `[[0,0],[0,1],[-1,1]]`
3. `point_in_room((0.5,0,0.5), [[0,0]])` true；`(1.6,0,0.5)` false
4. `aabb_in_room`：0.8×0.8 资产在单格中心 true、贴角越界 false
5. **多格跨格**：两格房 `[[0,0],[1,0]]`，资产中心在交界 `(1.55,0,0.775)` → true（内部格线不限）
6. `aabb_overlaps_xz`：相交 true / 相离 false / y 不同仍 true
7. `wall_axis_from_drag((0.4,0,0.2),(2.2,0,0.4))` → 水平；垂直拖 → 垂直
8. `wall_cells_from_drag`：从 `(0.775,0,0)` 水平拖到 `(3.875,0,0)` → 生成 2 段边界中点
   `[(1.55,0,0),(3.1,0,0)]` 附近（吸附后断言数量与轴）
9. `wall_position_in_room`：外边界上 true、房间内部 false
10. `next_size_tier` 循环；`SIZE_TIERS` 值 0.6/1.0/1.5
11. 模板序列化往返（含 walls 字段）：构造 → JSON.stringify → parse → 逐字段一致（容差 0.001）

### 10.3 场景级用例（实例化 asset_editor_3d.tscn）

1. 自由放置：`(0.4,0,0.3)` 精确保留、yaw 连续、scale 档位生效
2. 边界拒绝 / 重叠拒绝 / overlay 豁免（同 v2 前版）
3. **画墙**：程序调用画墙入口（模拟 A→B）→ Walls 子节点数 == 预期段数、yaw ∈ {0, π/2}、
   位置在格边界、`_rebuild_corners` 后 Corners 节点数正确
4. **拆墙**：选中一段墙 → 拖动（沿轴投影）→ 位置仍在边界；Delete → 墙少一段 + 转角重算
5. **三档大小**：幽灵 R 三次回到 1.0；选中资产 R → scale 变化与 meta 同步
6. **E 旋转**：模拟 e_held + 水平位移 → yaw 变化量正确（±容差）
7. **复制**：Ctrl+D → 新节点 +0.5 偏移、meta 完整
8. **参照物**：ReferenceActor 有子节点（莉莉模型或胶囊回退）、`ToggleActor` 切换可见性、
   切换房间后位置更新
9. **聚焦房间**：GroundMesh 材质 albedo == 深灰、RoomBase 底板格数 == 形状 cell 数、
   投影 quad 存在
10. 撤销/重做：摆 2 件 → 画 1 段墙 → undo → 墙消失 → undo → 资产 1 件 → redo ×2 恢复
11. **预置模板**：`_load_template("preset_kitchen_01")` → assets+wals 数量与 JSON 一致 →
    清空 → 保存用户模板 `__smoke_tpl` → 重载一致 → 删除该文件（user:// 受限则
    `print("CHANNEL_ASSET_EDITOR: NOTE user:// write unavailable (sandbox)")` 不判失败）
12. 相机 clamp：pitch 2.0 → 1.45；distance 99 → 40；F 聚焦后 orbit_center 更新

收尾格式同 v1：全部通过 `print("CHANNEL_ASSET_EDITOR: PASS ...")` + `quit(0)`。

## 11. Codex 执行步骤（严格按顺序）

1. 读本文件 + v1 的 4 个文件 + `godot/scripts/room_footprint_catalog.gd` +
   `godot/data/presentation_manifest.json`（找玩家 model_path）。
2. 新建 `godot/scripts/asset_diorama_rules.gd`（§5），先写 §10.2 规则单测跑通。
3. 生成 `godot/data/editor/preset_templates/` 下 3 个预置模板 JSON（§8.2）。
4. 改造 `godot/scenes/asset_editor_3d.tscn`（§7）。
5. 改造 `godot/scripts/asset_editor_3d.gd`（§6 全部交互 + §8 模板逻辑 + 参照物 + 聚焦房间）。
6. 改造 `godot/tests/asset_editor_smoke.gd`（§10 完整用例）。
7. headless 跑测试：
   `D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path G:\dream-channel\godot --script res://tests/asset_editor_smoke.gd`
   直到 `CHANNEL_ASSET_EDITOR: PASS`。
8. godot-mcp 连接运行中的 Godot，F6 运行 `asset_editor_3d.tscn`，按 §9 拍 7 张截图自查。
9. 跑正式回归确认无副作用：`smoke_test`、`pcg_diorama_stitch_smoke`。
10. 按项目规范提交（`feat(godot):` 前缀，只 add 改动文件，不加 `.import`/`.gd.uid`/lab_logs）。
    提交信息示例：`feat(godot): 地编工具 v2——拖拽画墙与模板拆墙、Unity 快捷键、莉莉参照物、三档大小、聚焦房间模式、预置模板库`
11. 报告交付：改动文件清单 + 测试输出 + 7 张截图路径 + 手动验收结果。

## 12. 验收清单（全部勾选才算完成）

- [ ] 规则单测（§10.2）与场景级用例（§10.3）全部通过
- [ ] 拖拽画墙：A→B 松手生成墙段、沿格边界 90°、自动转角收口、门洞/半墙/壁架可选
- [ ] 模板墙可拆可拖：选中墙段拖动/删除/复制，转角自动重算
- [ ] 3 个预置模板可加载，墙布局完整
- [ ] 资产连续自由摆放 + Ctrl 吸附 0.155m 细网格
- [ ] E+拖动自由旋转、R 三档大小（0.6/1.0/1.5）循环
- [ ] 单格房内资产不出格；多格房跨内部格线自由、不出外轮廓
- [ ] 越界/重叠红色提示拒绝落位；地毯 overlay 可叠加
- [ ] 右键环绕/中键平移/滚轮缩放/F 聚焦全部平滑，pitch 不钻地
- [ ] Ctrl+Z/Y 撤销重做覆盖放置/删除/拖动/旋转/大小档/复制/画墙/拆墙/加载模板
- [ ] 莉莉参照物显示正确比例、可隐藏、不干扰编辑
- [ ] 聚焦房间模式：深灰背景 + 高亮底板 + 投影，一眼区分房间与背景
- [ ] Unity 快捷键套件全部生效（§6.1 表）
- [ ] 模板保存/加载/刷新/删除可用，JSON 符合 §8.1
- [ ] 正式游戏回归（smoke_test、pcg_diorama_stitch_smoke）未破坏
- [ ] 未改动 asset_catalog.json 与任何正式游戏脚本；v1 遗留文件原样

## 13. 禁止事项（再犯即打回）

- ❌ 不允许回到 1.55m 整格吸附（连续自由是硬需求）
- ❌ 不允许做连续缩放（三档 0.6/1.0/1.5 是拍板值）
- ❌ 不允许墙脱离格边界或斜放（90° 吸附是拍板值）
- ❌ 不允许引入第三方插件或新的 asset library
- ❌ 不允许改正式游戏流程（channel_3d.tscn、pcg_diorama_stitch_lab 等）
- ❌ 不允许删除/修改 RoomBuilder3D、MetSys 遗留文件与 asset_catalog.json
- ❌ 不允许在拖动/旋转/画墙过程中频繁入撤销栈（只在操作完成时入栈）
- ❌ 不允许背景地面保持浅色（聚焦房间模式是拍板值）
