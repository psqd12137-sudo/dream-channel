# 地编模板接入正式对局：房间级模板覆盖 · 给 Codex

> 状态：实施计划（2026-08-22）
> 用法：把本文件全文粘贴给 Codex，让它按「执行步骤」逐条实施。
> 目标：地编工具里保存的房间模板，能在**正式对局**中按房间 ID 覆盖 PCG 生成的墙与家具，
> 从而把你手工搭的"微缩景观"在游戏里原样显示出来。
> 前置：请先通读本文件 + 下列文件，理解现状再改：
> - `godot/scripts/asset_editor_3d.gd`（地编工具：模板保存/加载、CardboardShellBuilder、堆叠落面）
> - `godot/scripts/room_art_registry.gd`（正式房间装饰入口 `decorate`）
> - `godot/scripts/channel_3d.gd`（正式主逻辑，重点 `_add_kenney_formal_composer` 2392–2452、`_populate_room_visual` 2534）
> - `godot/scripts/pcg_diorama_stitch_lab.gd`（PCG 房间生成，`_build_room_props` 793、`room_visual_roots`）
> - `godot/scripts/pcg_hand_layout_lab.gd`（Composer，`room_type` meta）
> - `godot/scripts/cardboard_shell_builder.gd`（纸板墙/门/转角构建）
> - `godot/data/editor/asset_catalog.json`（资产路径与 scale）

## 1. 现状与结论（先认清）

地编工具保存模板到 `user://diorama_templates/<name>.json`（如你刚保存的 `diorama_demo.json`：
单格房、5 件家具含 2 件堆叠、4 段墙含 2 个门洞）。**但正式对局完全不读这些模板**：

1. `channel_3d.gd` 的 `kenney_build_lab_mode := true`（默认开启）→ `_populate_room_visual`（2536 行）直接 `return`，**不调用 `RoomArtRegistry.decorate`**。
2. 正式房间由 `_add_kenney_formal_composer`（2415）用 `PCG_HAND_LAYOUT_LAB` 生成，每个房间是一个挂 `PCG_HAND_ROOM_SCRIPT` 的 piece，`piece.set_meta("room_type", room.get("id"))` 记录了房间 ID。
3. Composer 整体 `scale = HOUSE_CELL/1.55 ≈ 2.19`。

**结论**：要让模板在正式对局显示，必须在 **Kenney 拼装链路**里，对有模板的房间 ID（`room_type`），用模板的墙+家具覆盖 PCG 生成内容。坐标系需换算（模板 CELL=1.55 → 游戏 HOUSE_CELL=3.4，×2.19）。

## 2. 需求（用户已拍板）

| # | 决策 |
|---|---|
| R1 | **按房间 ID 匹配**：模板指定房间 ID（如 `living`/`kitchen`/`hall`），游戏里该 ID 的房间用模板覆盖 |
| R2 | **游戏端渲染纸板墙**：复用 `CardboardShellBuilder`，完整还原模板的墙/门/转角/堆叠，不用游戏默认简单墙 |
| R3 | **房间揭示时替换**：玩家走进该房间（揭示）时才用模板覆盖 PCG 内容 |
| R4 | **导出入库**：地编工具把模板导出为正式数据（写入 `res://data/editor/overrides/<room_id>.json`，随仓库入库） |

## 3. 文件与数据规格

### 3.1 模板导出的正式覆盖文件

地编工具新增"导出为正式数据"按钮，把当前模板写入：
`res://data/editor/overrides/<room_id>.json`（`room_id` 由用户输入，如 `living`）。

格式（schema v3，在 v2 基础上加 `room_id`，并**保留 v2 的家具/墙数据**）：

```json
{
	"schema_version": 3,
	"room_id": "living",
	"room_shape": "single",
	"room_rotation_quarters": 0,
	"assets": [
		{"id": "kk_couch", "position": [0.47, 0.0, 0.36], "yaw": 0.0, "scale": [0.28, 0.28, 0.28]}
	],
	"walls": [
		{"kind": "cb_wall", "position": [0.775, 0.02, 0.0], "yaw": 1.5708, "axis": [0, 0, 1], "cell": [0, 0]}
	]
}
```

- 字段含义与 v2 相同；`position`/`wall.position` 是**房间坐标系**（相对房间锚点原点，模板里以 `room_shape` 的 cells 最小角为原点，Codex 在 `make_template_json` 里已如此序列化）。
- `scale`：三轴值（含堆叠时家具的 Y 高度）。

### 3.2 游戏端只读加载

`room_art_registry.gd` 新增（static）：

```gdscript
const OVERRIDE_DIR := "res://data/editor/overrides/"

static func load_override(room_id: String) -> Dictionary:
	var path := OVERRIDE_DIR + str(room_id) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}
```

- 返回空字典表示该房间无模板；非空表示有覆盖。

## 4. 接入点与坐标换算（核心，Codex 重点）

### 4.1 覆盖时机（R3）

在 `channel_3d.gd` 的 Kenney 拼装 `/ Composer` 生成房间后，遍历所有 piece；对每个
`piece.get_meta("room_type")` 对应的房间，若 `RoomArtRegistry.load_override(room_type)` 非空，
则该房间的墙/家具**替换为模板内容**。

**推荐实现位置**：不直接塞进 `_add_kenney_formal_composer`（它一次性生成整栋），而是
在 `pcg_diorama_stitch_lab.gd` 的 **room 级生成函数**末尾加覆盖检查——因为每个房间的
`room_visual_roots[room_index]` 是房间专属视觉根节点，方便清空重画。

Codex 需在 `pcg_diorama_stitch_lab.gd`：
- 记录 `room_index → room_type`（从 `rooms[room_index].get("id", "")`，去掉 `@` 后缀取基础 ID，如 `living@1` → `living`）。
- 在 `_build_room_props` 等 room 级装饰后，`_apply_room_override(room_index, room_type, room_visual_roots[room_index])`。
- `_apply_room_override`：若 override 空则返回；否则清空该房间视觉根节点的**家具与墙子节点**，按模板重建（§4.2）。

> 注意：Kenney 桌模的墙/地板是拼接几何，替换时**只重画家具/墙装饰**，不动地板/门洞几何。
> Codex 用 godot-mcp 截图确认替换后房间仍连通、门洞正确。

### 4.2 坐标换算

- 模板坐标系：`CELL = 1.55`，房间锚点为 `room_shape` 的 cells（用 `Rules.rotated_cells` 旋转后）
  的最小角对齐世界原点（模板 `make_template_json` 已用此约定）。
- 游戏坐标系：Composer `scale = HOUSE_CELL / 1.55`，Composer 的 place 已按 `origin*1.55` 摆放，
  整体再 ×2.19。所以**模板坐标在接入时乘 `COMPOSER_SCALE = HOUSE_CELL/1.55` 即落到游戏世界**。
- 换算辅助（放到 `asset_diorama_rules.gd` 或 `room_art_registry.gd`）：

```gdscript
const COMPOSER_SCALE := 3.4 / 1.55  # 约 2.1935

static func override_world_position(model_pos: Vector3) -> Vector3:
	return model_pos * COMPOSER_SCALE

static func override_world_scale(model_scale: Vector3) -> Vector3:
	return model_scale * COMPOSER_SCALE
```

### 4.3 模板还原到游戏房间

`_apply_room_override(room_index, room_type, room_root)`：
1. `var ov := RoomArtRegistry.load_override(room_type)`；空则返回。
2. 遍历 `ov.get("assets", [])`：`load(id)` 实例化 → `position = override_world_position(asset.position)`
   → `rotation.y = asset.yaw` → `scale = override_world_scale(asset.scale)` → 挂到 room_root 的家具容器。
   （资产路径查 `asset_catalog.json`；堆叠的 Y 高度已含在 asset.position.y / scale 里，无需额外处理。）
3. 遍历 `ov.get("walls", [])`：`CardboardShellBuilder.build_wall(kind, position, yaw, color_index)`
   → `position = override_world_position(wall.position)` → 挂到 room_root 的墙容器；
   `cb_doorway` 用 `build_doorway`。
4. 门洞：模板的 `walls` 里 `cb_doorway` 即门洞；`build_doorway` 已含门扇。

### 4.4 房间 ID 提取

`room_type` 可能是 `"living"` 或 `"living@2"`（带实例后缀）。提取基础 ID：
```gdscript
func base_room_id(raw: String) -> String:
	return str(raw).split("@")[0].strip_edges()
```

## 5. 地编工具改动（R4）

`asset_editor_3d.gd` 新增：
- `UI/TopBar` 加 `OverrideRoomId`（LineEdit，placeholder `房间 ID，如 living`）+ `ExportOverride`（Button "导出到正式数据"）。
- `_export_override(room_id)`：读当前场景 → `make_template_json` → 写入
  `res://data/editor/overrides/<room_id>.json`（`DirAccess.make_dir_recursive_absolute` 创建目录）。
- 导出后状态栏提示路径；因为写在 `res://`，Codex 确认文件已生成（用于 git 入库）。

## 6. 测试规格

新增/更新测试：
1. `load_override`：给 `res://data/editor/overrides/test_room.json` 写一个测试模板 → `load_override("test_room")` 非空、字段正确 → 删除。
2. `base_room_id("living@2") == "living"`；`base_room_id("hall") == "hall"`。
3. 坐标换算：`override_world_position(Vector3(0.775,0,0.775)) ≈ Vector3(1.70,0,1.70)`（×2.1935）。
4. 场景级：实例化 Composer，给某房间注入一个单墙+单家具的 override，断言该房间视觉根节点生成了纸板墙与家具、数量正确。
5. 确认无 override 的房间不受影响（PCG 原样）。

## 7. Codex 执行步骤

1. 通读本文件 + §1 列出的所有前置文件。
2. 在 `asset_diorama_rules.gd` 或 `room_art_registry.gd` 加坐标换算与 `base_room_id`，先跑单测。
3. `room_art_registry.gd` 加 `load_override`。
4. 改造 `pcg_diorama_stitch_lab.gd`：room 级装饰后调 `_apply_room_override`（§4），接入纸板墙渲染。
5. 改造 `asset_editor_3d.gd`：加 `OverrideRoomId` 输入 + `ExportOverride` 按钮 + `_export_override`。
6. 写/更新测试（§6）。
7. **先用你已保存的 `diorama_demo.json`** 手工导出一个 override（如 `diorama_demo` → room_id 试 `living`），跑一次正式对局（F5 或用 godot-mcp 运行 `channel_3d.tscn`），玩家走进该房间截图，确认真实显示模板的墙+家具+堆叠。
8. 全部 headless 回归：`asset_editor_smoke`、`smoke_test`、`pcg_diorama_stitch_smoke`。
9. 按规范提交（`feat(godot):`）。示例：`feat(godot): 地编模板接入正式对局——房间 ID 覆盖、纸板墙渲染、坐标换算、导出正式数据`。
10. 报告：改动文件清单 + 测试输出 + 正式对局走进模板房间的截图 + §8 逐项打勾。

## 8. 验收清单

- [ ] 地编工具能导出 override 到 `res://data/editor/overrides/<room_id>.json`
- [ ] 游戏端 `load_override` 能读回；无 override 房间不受影响
- [ ] 房间揭示时，有 override 的房间显示模板墙+家具（含堆叠）
- [ ] 纸板墙在游戏内正确渲染（build_wall/build_doorway），门洞可通行
- [ ] 坐标换算正确（模板 1.55 → 游戏 3.4），家具位置、比例、堆叠不穿模
- [ ] 正式对局其余房间/战斗/PCG 回归未破坏
- [ ] `asset_editor_smoke` / `smoke_test` / `pcg_diorama_stitch_smoke` 通过
- [ ] 模板原始文件（`user://diorama_templates/`）不改动，导出是副本

## 9. 禁止事项

- ❌ 禁止改 `channel_3d.gd` 的正式对局流程主结构（只在 Composer / PCG 的 room 级装饰处勾接）
- ❌ 禁止直接改 `user://diorama_templates/` 里的原始模板（导出是副本）
- ❌ 禁止用游戏默认简单墙替代纸板墙（必须 `CardboardShellBuilder` 渲染，R2）
- ❌ 禁止把坐标换算做错（务必 ×COMPOSER_SCALE，否则家具/墙错位穿模）
- ❌ 禁止引入第三方插件/资产
- ❌ 禁止破坏 `kenney_build_lab_mode` 的其余房间生成
