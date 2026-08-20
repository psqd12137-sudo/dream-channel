# 2026-08-20：大地图与战斗房自由镜头

状态：客户端事实

基线：`origin/main` 的 `dd14bfa`。本记录随自由镜头提交一起入库。

## 本次完成

- 战斗房保留固定俯角的连续 360° 水平旋转，但旋转不再重新计算取景或把观察目标拉回房间中心。
- 战斗房和大地图都使用旋转无关的正交取景尺寸；取景只在场景初始化、地图内容变化或安全视窗尺寸变化时重算。
- 大地图获得与战斗房一致的自由旋转：空白世界区域左键拖动旋转，中键拖动平移，滚轮围绕指针缩放。
- 左键移动累计不足 `5px` 仍是地格点击；卡牌拖放、建造票根与 HUD 按钮优先于镜头手势。
- 建造按钮改名为“房间转向 90°”，明确它修改房间门向，而不是相机角度。
- 战斗墙面剔除增加 `0.42 / 0.28` 进入/退出迟滞，大地图继续复用 PCG 拼接器已有的相同迟滞和墙面家具同步规则。

## 关键文件与接口

- `godot/scripts/channel_3d.gd`
  - `battle_camera_zoom_ratio`：显式保存战斗缩放比例，视窗变化时按新 fit 恢复。
  - `house_camera_yaw / pitch / distance`：大地图镜头方向状态。
  - `_rotation_invariant_fit_size(...)`：按水平包围半径、固定俯角和视窗宽高比计算全角度稳定尺寸。
  - `orbit_battle_camera(...) / orbit_house_camera(...)`：只改变 yaw 和墙面表现，不改平移、缩放或拓扑。
- `godot/scripts/channel_3d_hud.gd`
  - `_house_overlay_has_point(...)`：阻止建造与房间操作 UI 被镜头拖拽吞掉。
  - `board_left_pressed / dragged / distance`：大地图与战斗房共用的点击/旋转手势判定。
- `godot/tests/camera_orbit_regression.gd`
  - 覆盖全角度稳定尺寸、缩放和平移保留、视窗变化、PCG 不变量、拖拽阈值和墙面迟滞。
- `godot/tests/capture_camera_orbit.gd`
  - 生成大地图与战斗房默认/旋转四张人工评审截图。

## 必须保持的不变量

- 自由旋转是纯表现操作，不得修改 `offer_rotation`、`room_rules.placed`、`connection_edges`、`visual_edge_records` 或 `generation_fingerprint()`。
- 战斗旋转不得修改 `combat.walls`、战斗格坐标或取格规则。
- 旋转过程中 `camera.size` 与观察目标必须保持不变；只有滚轮、平移、复位、地图范围或安全视窗变化可更新对应状态。
- 大地图墙面、门洞、开放通道和 wall-bound props 必须由同一次 `apply_camera_cutaway()` 同步切换。
- 房间朝向继续只由建造票根的 90° 转向控制，与连续镜头 yaw 完全独立。

## 已执行验证

- `res://tests/camera_orbit_regression.gd`：通过；覆盖 45°、90°、180°、360°、缩放后旋转、平移后旋转、视窗变化、PCG 账本和迟滞。
- `res://tests/battle_view_smoke.gd`：通过。
- `res://tests/input_intent_regression.gd`：通过。
- `res://tests/combat_input_regression.gd`：通过。
- `res://tests/kenney_formal_build_flow_regression.gd`：通过。
- `res://tests/pcg_diorama_stitch_smoke.gd`：通过。
- `res://tests/capture_camera_orbit.gd`：正常 Vulkan 渲染通过；截图写入 `godot/artifacts/camera_house_default.png`、`camera_house_rotated.png`、`camera_battle_default.png`、`camera_battle_rotated.png`，产物不提交。

## 下一阶段

- 当前只开放水平观赏旋转。若以后增加俯角调节，必须同步扩展稳定 fit 的 pitch 范围与墙面剔除验证，不能直接把纵向鼠标位移接到 pitch。
- 大型地图仍保留 `house_camera_fit_size <= 28` 的现有限制；当房间数量继续增长时，应评估分层、聚焦当前区域或提高上限，而不是在旋转时动态缩放。
