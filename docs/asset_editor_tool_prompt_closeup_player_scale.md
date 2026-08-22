# 地编工具 v6 方案：特写镜头 + 玩家动作防穿模 + 房间视觉放大 · 给 Codex

> 状态：实施计划（2026-08-23）
> 用法：把本文件全文粘贴给 Codex，用 godot-mcp 连接运行中的 Godot 截图自查、迭代视觉实现。
> 前置：override 墙的 camera cutaway 已修复（v5 基础上），本次做三项正式对局体验增强。
> Codex 动手前先通读本文件 + 下列文件：
> - `godot/scripts/channel_3d.gd`（3805 行：镜头/玩家/房间主逻辑）
> - `godot/scripts/pcg_diorama_stitch_lab.gd`（2430 行：房间生成/交互槽/override）
> - `godot/scripts/pcg_hand_layout_lab.gd`（Composer）
> - `godot/scripts/character_presenter.gd`（玩家模型/动画）
> - `godot/scripts/asset_diorama_rules.gd`（规则常量）
> - `godot/data/editor/overrides/living.json`（示例 override）

## 1. 现状与三个问题

### 1.1 玩家"没动作/穿模"
**现状**：玩家用 `CharacterPresenter`（`_add_house_player`，channel_3d 2691），通过 `claim_room_interaction_slot` 找交互槽，`set_interaction_pose` 播 `sit/stand/work` 动画，位置来自 `_interaction_slot_house_position`（anchor）。交互槽由默认 PCG 家具生成（`_build_room_interaction_slots`），存在 `interaction_slot_records`。

**根因**：**override 房间用模板家具替换了默认家具，但 override 家具不生成交互槽**——`_build_room_interaction_slots` 只在默认 PCG 家具流程里跑。所以 override 房间里 `interaction_slot_records` 仍是「被隐藏的默认家具」的槽位，玩家落到那个位置（对准被隐藏的默认家具），与模板家具错位 → **穿模、没动作**。

### 1.2 特写镜头缺失
**现状**：正交相机 `camera.size`，`_set_house_camera`（3315）按整栋房子拟合全景（`house_camera_fit_size`）。进房间没有特地拉近，一直是全景。

### 1.3 房间视觉偏小/拥挤
**现状**：玩家走格 `HOUSE_CELL=3.4`，Composer `scale=HOUSE_CELL/1.55≈2.19`。override 家具坐标在 `_apply_room_override` 里按模板 1.55 系换算（`_override_local_position`）。**问题**：你的 `living` 模板 5 件家具挤在单格（尺寸 0.28，占格子比例大），模板家具相对格子占比太高，显得挤。

## 2. 需求（用户已拍板）

| # | 需求 |
|---|---|
| D1 | **特写镜头**：玩家进房间时，镜头从全景拉近到该房间特写，聚焦房间内景（看得到家具和玩家）；可手动切换回全景（如 C 键） |
| D2 | **玩家动作 + 防穿模**：玩家进房间播放符合 override 家具的待机/互动动画（sit/stand/work），走位到 override 家具对应的落脚点，不穿模 |
| D3 | **房间视觉放大**：放大房间视觉尺度，让 override 家具放得下、不拥挤（玩法格子数/逻辑不变，只调视觉比例） |

## 3. 实现规格

### 3.1 玩家动作 + 防穿模（D2，核心，先做）

**问题本质**：override 房间需要**为 override 家具生成交互槽**，让玩家能落到模板家具上。

**方案 A（推荐，最小侵入）**：`_apply_room_override` 里，为每个 override 家具生成一个交互槽（由 `asset_catalog` 里该资产的 `INTERACTION_PROFILES` 或 `room_prop_catalog.gd::INTERACTION_PROFILES` 提供 pose/anchor/approach）。

- 在 `_apply_room_override` 生成 `furniture_root` 的每个家具后，调 `_add_override_interaction_slot(room_index, cell, asset_id, furniture_position, yaw, scale)`。
- `_add_override_interaction_slot`：
  ```gdscript
  func _add_override_interaction_slot(room_index, cell, asset_id, world_pos, yaw, scale) -> void:
      var profile := RoomPropCatalog.interaction_profile(asset_id)  # 返回 {kind, pose, approach, anchor}
      if profile.is_empty():
          profile = {"kind":"stand", "pose":"stand", "approach":Vector3(0,0,0.3), "anchor":Vector3(0,0,0)}
      var slot := {
          "room_index": room_index, "room_id": ..., "cell": cell,
          "kind": profile.get("kind","stand"), "pose": profile.get("pose","stand"),
          "asset_id": asset_id, "position": world_pos + profile.get("approach",Vector3(0,0,0.3)) * scale,
          "anchor_position": world_pos + profile.get("anchor",Vector3(0,0,0)) * scale,
          "facing_yaw": yaw + PI, "slot_index": room_index*10 + <内联索引>,
      }
      interaction_slot_records.append(slot)
  ```
  - `kind`/`pose` 对应动画（sit/rest/work/stand/tend/browse/cook），`position`/`anchor` 用家具的世界位置 + approach 偏移（按 scale 缩放），保证玩家站到家具前/上不穿模。
- **注意**：override 房间原本的 `interaction_slot_records` 需要**清掉该房间的旧槽**（`room_id` 匹配的），否则残留被隐藏家具的槽位会继续导致错位。在 `_apply_room_override` 开头，把 `interaction_slot_records` 里 `room_id` == 该房间的删掉再新增。

**动画播放**：`_add_house_player` 里 `presenter.set_interaction_pose(pose, kind)` 已能播；确保 override 槽位的 pose 传入。`character_presenter.gd` 的 `_play_model_animation` 读 `animation_map[state]`，需确认 override 家具的 pose 对应的动画名存在（默认 sit/rest/work/stand 都有映射）。

### 3.2 特写镜头（D1）

**方案**：加一个 `house_camera_closeup` 状态。
- `_add_house_player` / 进入房间时（`_set_house_camera` 或房间切换回调）触发：若玩家在当前房间且房间有内容，把 `camera.size` 从全景 `house_camera_fit_size` 缩到 `closeup_fit_size`（聚焦当前房间，约 `HOUSE_CELL * 2.6`），`house_camera_target` 设为玩家位置（保持偏上构图 `HOUSE_CAMERA_FRAME_OFFSET`）。
- **手动切换**：C 键 `toggle_house_camera_closeup()`：在全景 ↔ 特写间切换。切到全景恢复 `_set_house_camera` 的 `house_camera_fit_size`，切到特写用 closeup。
- **触发时机**：`phase` 进入 `explore/room_ready`（玩家在当前房间）时自动特写；离开房间（走格完成、`current_room_pos` 变化）返回全景。参考 `_update_camera_follow`（376）和 `_set_house_camera` 的 `house_camera_fit_size` 计算。
- **平滑**：特写/全景切换用 `_update_camera_follow` 的指数平滑（`CameraFollowMath.smooth_factor`），不要瞬切。

### 3.3 房间视觉放大（D3）

**方案**：不动玩法格数，只放大房间/家具的视觉尺度。两处：
- **override 家具 scale**：`_apply_room_override` 里 `model.scale = _array_vec3(asset.scale)` —— 目前直接用模板 scale（0.28）。改为乘一个 `OVERRIDE_SCALE_FACTOR`（如 1.15~1.3），让家具相对格子更大、更"填满"。但**不能塞满/穿模**，需截图调参。
- **房间整体**：`composer.scale = HOUSE_CELL/1.55` 已把房间放大到 3.4 米格。若仍嫌小，可把 `HOUSE_CELL` 视觉放大（但要同步玩家走格、战斗 grid，风险大）。**建议先只调 override 家具 scale**，避免动玩法坐标。
- **参数**：`const OVERRIDE_SCALE_FACTOR := 1.25`（可调，截图验证占比合适、不穿模）。

## 4. 文件改动清单

| 文件 | 动作 |
|---|---|
| `godot/scripts/pcg_diorama_stitch_lab.gd` | **改**：`_apply_room_override` 为 override 家具生成交互槽（清旧槽+新增）；`OVERRIDE_SCALE_FACTOR` 调家具 scale |
| `godot/scripts/channel_3d.gd` | **改**：特写镜头状态（`house_camera_closeup`）、C 键切换、进/离房间自动触发；玩家用 override 槽位 |
| `godot/scripts/character_presenter.gd` | **改**：确认/补齐 override 家具 pose 对应动画名 |
| `godot/tests/*` | **改**：新增 override 交互槽生成、特写镜头切换的测试 |

## 5. 测试规格

1. **override 交互槽**：给 room 注入 living override，断言 `_apply_room_override` 后该房间 `interaction_slot_records` 数量 == override 家具数（5），且每个槽 `asset_id` 匹配、`position` 不穿模（槽位置与家具 AABB 无交叠）。
2. **清旧槽**：override 应用后，被隐藏默认家具的旧槽已从 `interaction_slot_records` 移除（该房间的 old slots 不存在）。
3. **特写切换**：`toggle_house_camera_closeup()` 后 `camera.size` 从全景缩小到 closeup；再切回恢复。`current_room_pos` 变化时自动回全景。
4. **玩家落位**：`_add_house_player` 在 override 房间选中一个 override 槽位，`presenter` 收到对应 `pose`，玩家位置不在家具 AABB 内。
5. **D3 scale**：`OVERRIDE_SCALE_FACTOR` 生效，家具 scale 放大但仍 `aabb_in_room` 不越界。

## 6. Codex 执行步骤

1. 通读本文件 + §1 列出的前置文件。
2. 先做 D2：`_apply_room_override` 清旧槽 + 为 override 家具生成交互槽（§3.1），写 §5 测试 1/2/4。godot-mcp 截图确认玩家站上模板家具不穿模、pose 正确。
3. 再做 D1 特写镜头（§3.2），§5 测试 3。截图确认进房间自动拉近、C 键切换平滑。
4. 最后 D3 房间放大（§3.3），调 `OVERRIDE_SCALE_FACTOR` 截图确认家具占比合适不穿模、不挤。
5. 全量回归：`asset_editor_smoke`、`smoke_test`、`pcg_diorama_stitch_smoke`、`formal_override_integration_smoke`、`formal_override_export_smoke`。
6. 按规范提交（`feat(godot):`）。
7. 报告：改动清单 + 测试输出 + 特写/玩家落位/放大前后对比截图 + §7 逐项打勾。

## 7. 验收清单

- [ ] 玩家进 override 房间落位到模板家具槽位，**不穿模**
- [ ] 玩家播放对应待机/互动动画（sit/stand/work）
- [ ] 进房间镜头自动拉近特写，聚焦房间内景
- [ ] C 键手动切换特写/全景，平滑无跳变
- [ ] 离开房间返回全景
- [ ] 房间视觉放大后家具占比合适，不挤不穿模
- [ ] 玩法格子数/战斗/PCG 回归未破坏
- [ ] 全部 headless 测试通过

## 8. 禁止事项

- ❌ 禁止改玩家走格的 `HOUSE_CELL`（会破坏玩法坐标/战斗）
- ❌ 禁止移动 override 家具 AABB 判定（可放大 scale 但必须 `aabb_in_room` 守住）
- ❌ 禁止在 override 房间残留被隐藏默认家具的交互槽（会导致穿模）
- ❌ 禁止放大家具后穿模/塞满（必须截图验证占比）
- ❌ 禁止引入第三方插件
