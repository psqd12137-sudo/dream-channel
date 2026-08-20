# 2026-08-20 大房间节奏实验交接

状态：已在后台测试入口实现，尚未转正到正式开局。

## 改动范围

- “后台测试 → 桌模扩建 PCG”启用隔离的 `large_room_mix_test_mode`。
- 测试池把客厅、厨房、温室、卧室、育儿室升为三格房，把后院升为五格房；运行时普通房间池由原来的小房占优变为 `6 个单格 / 10 个三格 / 5 个五格`，另有单格玄关。
- 测试三选一按 1/3/5 格分桶，不再让布局 profile 的最高排序分数包办三张票根。
- 12 房软节奏为 `1,3,3,5,3,1,3,5,3,1,3,1`，目标是含玄关 `4 个单格 / 6 个三格 / 2 个五格`；当前房间是单格时优先隐藏下一张单格，大房候选不足三张时才用单格补足票根。
- 同一多格房在测试模式下统一选择深色或普通木地板 finish，减少逐格拼贴感。
- 测试 HUD 显示已摆放的 1/3/5 格计数和目标配额。

## 关键文件与接口

- `godot/scripts/channel_3d.gd`：测试模式、房型覆盖、尺寸分桶、节奏配额、存档隔离和诊断文本。
- `godot/scripts/pcg_diorama_stitch_lab.gd`：`unify_room_floor_finish`，默认关闭，仅测试入口开启。
- `godot/scripts/channel_3d_hud.gd`：大房间实验标签和实时尺寸计数。
- `godot/tests/large_room_mix_lab_regression.gd`：验证房型池、票根多样性、玄关后无连续单格、统一地板和正式流程隔离。
- `godot/tests/capture_large_room_mix_lab.gd`：生成票根、落位、进入房间三张截图。

## 必须保持的不变量

- 正式 `start_new_run`、续局存档和 `room_footprint_catalog.gd` 不得读取实验房型覆盖。
- 测试模式不得写 `user://channel_run_v1.json`，避免覆盖玩家正式进度。
- 所有测试房仍通过 `room_rules.valid_rotations/place` 摆放，不绕过门位、占用、连接边或可达性规则。
- `unify_room_floor_finish` 只统一同房地板变体，不合并逻辑格、不改变交互槽位和家具净空。
- 房间尺寸不足以形成三种合法票根时允许同尺寸重复；合法大房候选不足三张时才用单格兜底。

## 实际验证

- `large_room_mix_lab_regression.gd`：PASS。
- `kenney_formal_build_flow_regression.gd`：PASS。
- `formal_build_promoted_regression.gd`：PASS。
- `room_footprint_regression.gd`：PASS。
- `pcg_diorama_stitch_smoke.gd`：PASS。
- `run_progression_save_regression.gd`：PASS。
- `input_intent_regression.gd`：PASS。
- `capture_large_room_mix_lab.gd`：PASS；人工检查 `large_room_mix_01_offers.png`、`large_room_mix_02_placed.png`、`large_room_mix_03_entered.png`，玄关后为 3/5/5 格票根，三格厨房地板统一且读作一个房间。

## 建议下一步

- 先试玩多个 Seed，记录 12 房完成局的实际尺寸分布、地图包围盒和大房合法摆放失败率，再决定是否转正。
- 若正式转正，不要直接覆盖 `ROOM_CONFIG`；先把尺寸选择规则与布局轮廓 profile 解耦，并为旧存档增加明确迁移策略。
