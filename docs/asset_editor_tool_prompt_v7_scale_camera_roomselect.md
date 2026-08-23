# 地编工具 v7 方案：格子视觉放大 + 地编选房 + 镜头时机 · 给 Codex

> 状态：实施计划（2026-08-23）
> 用法：把本文件全文粘贴给 Codex，用 godot-mcp 连接运行中的 Godot 截图自查、迭代视觉。
> 前置：override 模板已接入正式对局（v5/v6 基础上）。本次三项均为正式对局 + 地编联动。
> Codex 动手前先通读本文件 + 列出的前置文件。

## 1. 现状与三个问题

### 1.1 房间格子偏小，家具挤
override 家具在 `_apply_room_override` 里被 `OVERRIDE_SCALE_FACTOR := 1.25` 放大，但房间格子没变 → 家具相对格子变大，显得挤。用户希望**先把格子基础尺寸**做视觉放大，让家具放得下。

### 1.2 地编工具无法按"正式房间"选择修改
现在地编工具只按房间形状（single/line3/l3 等）编辑，无法选择"当前对局的真实房间"（living/kitchen/hall 等）。

### 1.3 每次进新格子都放大摇镜头
`enter_room`（1535）/`_finish_enter_room`（1620-1621）每次进房间都强制
`house_camera_closeup = true` + `house_camera_following = true` → 每进一格都特写运镜。
用户期望：**进普通房间不摇；只有退出战斗/事件回大地图时才摇**。

## 2. 需求（用户已拍板）

| # | 决策 |
|---|---|
| D1 | **格子视觉放大**：只放大房间视觉观感，不重算玩家走格/战斗玩法坐标（风险最小）。参考做法：调 `composer.scale`（现在是 `HOUSE_CELL/1.55`），让房间更开阔、家具不挤。**
| D2 | **地编按正式房间选择**：地编工具下拉选择正式房型表（`living/kitchen/hall/...`），显示房间形状/格数，在放大的格子里编辑 |
| D3 | **镜头时机**：进普通房间不强制特写运镜；只有**退出战斗/事件回大地图**时才特写摇镜头 |

## 3. 实现规格

### 3.1 格子视觉放大（D1，先做，风险最小）

**关键约束**：`HOUSE_CELL = 3.4`（玩家走格 `_house_world` 用它，**玩法坐标不能动**）。
房间视觉由 Composer 放大（`composer.scale = HOUSE_CELL/1.55 ≈ 2.19`，把 1.55 逻辑格 > 3.4 视觉）。

**方案 A（推荐，最安全）**：只调 `composer.scale` 增大，让房间视觉更大，但**玩家走格不动、战斗 grid 不动**。由于玩家走格用 `_house_world(pos)=pos*HOUSE_CELL`（逻辑格映射到 3.4 间距），房间视觉若放大到 >3.4，玩家就可能走到房间墙外。**需要截图验证玩家落点与房间墙对齐**。

因此更稳妥的做法是：
- 新增常量 `VISUAL_CELL_SCALE := 1.30`（视觉放大倍数，可调），`composer.scale = Vector3.ONE * (HOUSE_CELL / 1.55) * VISUAL_CELL_SCALE`。
- **同步**：玩家走格（`_house_world`）、战斗 grid、交互槽、override 家具坐标都要乘同一倍数，否则错位。但这会动玩法坐标（违背"不重算玩法坐标"）。**矛盾点**。
- **折中（推荐）**：**不改玩法坐标**（`HOUSE_CELL`、`_house_world` 不动），只把**房间内部视觉**（Composer 的房间壳体/家具）放大，但**墙/地板仍对齐 `_house_world` 的 3.4 间距**。即放大的是"家具的相对大小"而非"格子间距"——**改 `OVERRIDE_SCALE_FACTOR` 和 Composer 内部家具 scale，而不是 `HOUSE_CELL`**。

**最终判定**：用户说"先拓展所有格子基础大小"——最贴合的是**放大格子视觉**，让房间显得更大。但我前面确认用户选"只放大视觉不重算玩法坐标"。所以：
- **D1 具体做法**：`composer.scale` 用 `(HOUSE_CELL/1.55) * VISUAL_CELL_SCALE` 放大视觉；**同时**玩家 token 位置、交互槽、override 家具乘 `VISUAL_CELL_SCALE` 对齐（这些是房间内相对位置，不是绝对玩法 grid，乘积后仍对齐房间中心）。**战斗 grid 不改**（战斗用自己的 `battle_world`）。
- **验收**：放大后玩家走进房间，站在家具前不穿模、不走到墙外；家具不挤。用 godot-mcp 截图前后对比。

### 3.2 地编按正式房间选择（D2）

- 地编工具加载正式房型表 `room_footprint_catalog.gd::ROOM_CONFIG`（含 `living/kitchen/hall/...` 及 `shape`）。
- `UI/TopBar` 加 `FormalRoom`（OptionButton），列出所有正式房间 id（living/kitchen/study/bedroom/...），选择后：
  - 用该房间的 `shape`（single/line3/l3/plus5/...）设置 `room_shape`（`_change_room`）
  - 显示房间格数（`ROOM_CONFIG[room_id].shape` 对应格数）
  - 编辑时以该房间为锚点，在放大后的格子里摆放 furniture/墙
- 选择后 `_export_override(room_id)` 用它作为 override 键。

### 3.3 镜头时机（D3，纯逻辑，改动点明确）

**现状**：`enter_room`（1535）/`_finish_enter_room`（1620）每次进房间强制 `house_camera_closeup=true` + `house_camera_following=true`。

**改法**：
1. **删掉** `enter_room` 和 `_finish_enter_room` 里强制 `house_camera_closeup = true`；进普通房间保持全景（`house_camera_closeup = false`），只保留 `house_camera_following` 的**适度跟随**（或按需）。
2. **只在退出战斗/事件回大地图时**触发特写运镜。定位战斗/事件结束回 explore 的入口：`_after_combat_action`（2327）、以及奖励完成/事件结束回 `phase="explore"` 的地方。在这些地方设置 `house_camera_closeup = true` + `house_camera_following = true`（+ 触发 `_start_camera_intro` 或 closeup 运镜）。
3. **触发时机表**（Codex 逐一核对）：
   - 进普通房间（初次无关格内容）：**不摇**
   - 进战斗/事件房间：不摇（战斗用自己的 battle camera）
   - **战斗结束**（`_after_combat_action` → `phase="explore"`）：**摇**（特写回大地图）
   - **事件结束**（`start_event_trial` 完成后 → `phase="explore"`）：**摇**
   - 任务完成回 explore：**摇**（或按需）

> 注意：`house_camera_closeup` 是 Codex 已加的"特写镜头"状态（`_set_house_camera` 用它切 closeup 尺寸）。D3 调整它的触发时机，而非功能。
> Codex 用 godot-mcp 实际走一遍：进普通房间（不摇）、打一场战斗（结束回大地图摇）、进事件（结束摇），截图确认。

## 4. 文件改动清单

| 文件 | 动作 |
|---|---|
| `godot/scripts/channel_3d.gd` | **改**：`VISUAL_CELL_SCALE` 常量；`composer.scale` 乘倍数；进入房间 closeup 时机（D3）；战斗/事件结束触发 closeup |
| `godot/scripts/pcg_diorama_stitch_lab.gd` | **改**：override 家具 scale 乘 `VISUAL_CELL_SCALE`；`OVERRIDE_SCALE_FACTOR` 改 1.0（不重复放大，视觉放大交给 VISUAL_CELL_SCALE 统一） |
| `godot/scripts/asset_editor_3d.gd` | **改**：`FormalRoom` 下拉加载 ROOM_CONFIG；选房联动 room_shape/override |
| `godot/scripts/asset_diorama_rules.gd` | **改**：`VISUAL_CELL_SCALE` 参与 override 换算（若需要） |
| 测试 / 文档 | 更新回归测试与方案文档 |

## 5. 测试规格

1. **VISUAL_CELL_SCALE 生效**：`composer.scale` 增大 `VISUAL_CELL_SCALE` 倍；override 家具 scale 同样增大（不出现家具/房间不同步）。
2. **玩家落点对齐**：放大后玩家 token 位置仍在房间中心、不走到墙外（`_house_world` 不变情况下，玩家位置乘倍数对齐）。
3. **镜头时机 D3**：
   - `enter_room` 到普通房间后 `house_camera_closeup == false`（不再强制特写）
   - `_after_combat_action` 到 explore 后 `house_camera_closeup == true`（战斗结束摇）
   - 事件结束回 explore 同理 `== true`
4. **地编选房 D2**：`FormalRoom` 下拉含 `living`，选择后 `room_shape_id` 更新为对应 shape；`_export_override("living")` 写入 living.json。

## 6. Codex 执行步骤

1. 通读本文件 + `channel_3d.gd` / `pcg_diorama_stitch_lab.gd` / `asset_editor_3d.gd` / `asset_diorama_rules.gd` / `room_footprint_catalog.gd`。
2. 先做 D1（VISUAL_CELL_SCALE + composer.scale + override 家具同步），截图放大前后，确认家具不挤、玩家不走墙外。
3. 再做 D3（镜头时机），先改 `enter_room`/`_finish_enter_room` 去掉强制 closeup，再加战斗/事件结束触发。godot-mcp 走一遍进房/战斗/事件，截图确认。
4. 再做 D2（地编 FormalRoom 下拉）。
5. 写 §5 测试，全量回归：`asset_editor_smoke`、`smoke_test`、`pcg_diorama_stitch_smoke`、`formal_override_integration_smoke`、`formal_override_export_smoke`。
6. feats 提交（`feat(godot):`）。
7. 报告：改动清单 + 测试 + 放大前后/镜头时机截图 + §7 逐项打勾。

## 7. 验收清单

- [ ] 房间视觉明显放大，家具不挤、不穿模
- [ ] 玩家走进房间仍在中心，不走到墙外
- [ ] 地编工具按正式房间下拉选择（living/kitchen/hall），联动 room_shape + override
- [ ] 进普通房间**不**强制特写运镜
- [ ] 退出战斗**摇**（特写回大地图）
- [ ] 退出事件**摇**
- [ ] 战斗 grid / 玩家玩法走格回归未破坏
- [ ] 全部 headless 测试通过

## 8. 禁止事项

- ❌ 禁止改 `HOUSE_CELL`（3.4）玩家走格 / 战斗 grid 的**玩法坐标**
- ❌ 禁止 override 家具与房间视觉不同步（家具要么都乘 VISUAL_CELL_SCALE，要么都不乘）
- ❌ 禁止 `OVERRIDE_SCALE_FACTOR` 与 `VISUAL_CELL_SCALE` 双重放大（用后者统一）
- ❌ 禁止进普通房间仍强制特写（D3 核心）
- ❌ 禁止引入第三方插件
