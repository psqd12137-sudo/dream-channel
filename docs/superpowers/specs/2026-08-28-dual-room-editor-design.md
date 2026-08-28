# 大地图格子房与副本房间双层地编设计

## 目标

让 Godot 的 `Asset Editor` 同时编辑两种空间表现：大地图上的 1/3/5 格格子房，以及进入后对应的副本房间。两层共享房间类型和默认 footprint 比例，但使用独立布局数据。

## 现有边界

- `room_rules.placed` 已将多格占地视为一个 `instance_id`；3/5 格的所有占用格共享揭示、事件和完成状态。
- `room_size / footprint_kind / footprint` 负责大地图几何；`encounter_tier / pace_role` 负责内容节奏。
- `asset_editor_3d.gd` 当前只编辑房间布景，导出 `data/editor/overrides/<room_id>.json`。
- 敌人、战斗棋盘、事件、奖励和存档规则不属于地编工具职责。

## 数据模型

大地图房间实例继续使用现有字段，并在需要生成副本时增加关联：

```text
world_room_instance.instance_id
  -> dungeon_ref.dungeon_layout_id
```

编辑器层面使用一个静态映射清单把正式房间类型映射到默认副本布局 ID：

```json
{
  "schema_version": 1,
  "links": [
    {
      "world_room_id": "boiler",
      "dungeon_layout_id": "boiler_dungeon_01",
      "footprint_mode": "inherit"
    }
  ]
}
```

副本布局保存为 `data/editor/dungeon_layouts/<dungeon_layout_id>.json`，包含 `schema_version`、`dungeon_layout_id`、`source_world_room_id`、`footprint_kind`、`footprint`、`room_rotation_quarters`、`assets`、`walls` 和 `fixtures`。

副本布局不存在时，编辑器从对应大地图正式 override 或房间目录生成临时初稿；只有点击“导出副本布局”才创建独立副本文件。副本 footprint 默认继承大地图房间，但可以在副本编辑层单独调整。

## 工具交互

现有 Asset Editor 顶部增加“编辑层”选择：

- `大地图格子房`：沿用现有正式房间选择、`overrides/<room_id>.json` 导出和兼容行为。
- `副本房间`：选择来源大地图房间，显示其映射的 `dungeon_layout_id`，从副本文件或大地图 override 载入布局，导出到 `dungeon_layouts/`。

房间形状、旋转、家具、墙、门和参照物操作在两层共用；切换编辑层前保存当前编辑器快照，切换后载入目标层，避免把未保存编辑误写入另一层。

## 兼容与错误处理

- 原有大地图导出格式和路径保持不变。
- 缺失或无效映射时显示警告并使用 `<world_room_id>_dungeon_01` 的确定性默认 ID。
- 缺失或无效副本布局时回退到大地图 override/自动初稿，不阻塞编辑器启动。
- 副本布局只保存空间数据，不复制敌人、战斗棋盘、事件或奖励字段。

## 测试验收

- 映射清单覆盖所有 `RoomFootprintCatalog.ROOM_CONFIG` 房间，副本 ID 确定且不重复。
- 默认副本 footprint 与来源房间的 1/3/5 格形状和格数一致。
- Asset Editor 可在两层之间切换；副本层读取独立布局，缺失时正确回退；导出路径和字段正确。
- 现有房间 footprint、房间美术和正式 override 回归测试继续通过。
