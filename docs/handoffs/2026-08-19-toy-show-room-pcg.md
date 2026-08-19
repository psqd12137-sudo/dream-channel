# 2026-08-19：玩具秀房间 PCG 与角色占位

状态：客户端事实

基线：`origin/main` 的 `129c1db`。本记录随对应功能提交一起入库。

## 本次完成

- 产品名和美术定位统一为《织梦频道》：荒诞儿童玩具秀中的纸板、黏土、毛毡微缩布景。`Virtual Cottage 2` 仅用于研究宜居密度和家具交互，《山屋惊魂》仅保留玩法结构参考。
- 普通新局使用随机种子；标题页支持输入、复用和复制种子码。种子同时确定房屋布局档案与房间陈设，同一种子可复现。
- 正式大地图使用程序化纸板墙、折边、胶带、支撑脚、转角柱和纸板门。相连房间都访问后门组件消失，只保留低门槛；连接账本和门洞数量不变。
- 房间访问状态控制整房揭示。未访问房间不生成可见家具；玩家进入不会推动家具或重新生成陈设。
- 引入 KayKit Furniture Bits（上游 `96d5930`，CC0）和现有 Quaternius 补充资产。家具按客厅、卧室、厨房、书房、温室、地下室主题，以 2-3、4-6、6-8 件预算确定性摆放。
- 每个逻辑格提供四个稳定演员槽位。家具可提供坐、休息、工作、烹饪、阅读、照料、交谈和取暖语义；同格最多四名演员，第五名无法占用。
- 家具逐表面复制导入材质，再施加毛毡、刷漆木或黏土的高粗糙度覆盖。原贴图与共享导入资源不被修改。
- 每个已访问房间生成地面走位胶带和墙面节目装置。六类房型分别绑定掌声循环、错误梦境眼睛、冷炉冰柱、重写提词卡、塑料雨、后台敲击异常；异常只改变表现并随墙面剔除。

## 关键文件与接口

- `godot/scripts/pcg_diorama_stitch_lab.gd`
  - `set_room_broadcast_glitch(room_index, active)`：切换正常播出与房型异常。
  - `interaction_slots_for_cell(cell)`：返回一个格子的四个演员槽位。
  - `props_use_handmade_finishes()`、`theme_anomalies_are_valid()`：美术约束验证。
  - `production_fixtures_are_valid()`、`cardboard_shell_is_valid()`：节目装置与纸板壳体验证。
- `godot/scripts/room_prop_catalog.gd`
  - 共享家具目录、房型组合、交互语义、手工材质分类和主题异常映射。
- `godot/scripts/channel_3d.gd`
  - 新局种子、布局档案、正式地图门状态，以及演员槽位申请和释放。
- `godot/scripts/channel_3d_hud.gd`
  - 种子输入、按种子开局和复制种子入口。

## 必须保持的不变量

- 家具、演员槽位、走位胶带和节目装置都是表现层，不得写入 PCG 连接账本、战斗墙、导航或存档拓扑。
- 玩家进入房间只能选择空槽，不能触发家具避让、重排或重新随机。
- 门消失只由连接两侧均已访问驱动，不能删除规范连接边或改变可达性。
- 靠墙家具和节目装置必须绑定规范边，并与对应墙面一起执行镜头剔除。
- 同一种子与同一房间实例 ID 必须得到相同家具布局；访问状态只控制揭示。

## 已执行验证

- `res://tests/pcg_diorama_stitch_smoke.gd`：通过，包含 25 个 Seed 扫描。
- `res://tests/kenney_formal_build_flow_regression.gd`：通过，覆盖 1 格门厅到 5 格房间、进房开门、揭示、家具稳定和多人槽位。
- `res://tests/run_progression_save_regression.gd`：通过，覆盖随机/指定种子、存档和继续游戏。
- `res://tests/input_intent_regression.gd`：通过。
- `res://tests/multi_room_build_regression.gd`：通过，覆盖五格房间整体放置与动画。
- `res://tests/dynamic_effects_smoke.gd`：通过，覆盖房间落下、角色移动、隐藏揭示和输入锁。
- `res://tests/capture_cottage_room_props.gd`：通过，生成 1/3/5 格默认、旋转和异常截图到 `godot/artifacts/toy_show_props/`；该目录被忽略，不入库。

## 建议下一步

- 为六种房型各做一张近景正常/异常对照，检查异常符号在所有相机方向上的辨识度。
- 将同一主题目录和演员槽位请求接口同步到战斗房，但不要直接复制大地图的陈设密度。
- 最终资产替换时保留现有规范边、净空、房型标签和交互槽位契约，只替换表现资源。

## 未纳入本次提交

- `godot-mcp-pro-v1.16.0/`：本地 MCP 工具。
- `apps/`、`cabin-slice/`：当前工作区中的未跟踪本地目录。
- `godot/artifacts/`：测试截图产物。
