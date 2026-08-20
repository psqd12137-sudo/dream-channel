# 2026-08-20 正式 UI 视觉整理交接

状态：已实现并完成回归与截图检查。

## 改动范围

- 正式主页使用“织梦频道”作为唯一产品名，重排主操作、自定义种子和右上角后台测试入口。
- 顶栏高度统一为 72px，移除正式流程中的 EXE hash、`3D BRIDGE`、PCG/KayKit/ROT 等开发信息。
- 探索右栏改为节目状态、进度、预兆和导播记录四层；PCG 诊断仅在桌模后台测试入口显示。
- 建造 UI 改为地图下方全宽操作带，票根使用中文房型、门型和方向，命令区不再遮挡地图。
- 预兆、奖励和战斗手牌重做层级、比例、色彩与文案；战斗棋盘在底部手牌安全区前截止。

## 关键文件与接口

- `godot/scripts/channel_3d_hud.gd`：全部正式 HUD 绘制、布局矩形、卡牌与票根视觉。
- `godot/scenes/combat_ui_layout.tscn`：`IntentArea`、`ActionArea`、`HandArea`、`DeckArea`、`DiscardArea` 的 1280 x 800 设计坐标。
- `godot/scripts/channel_3d.gd`：`show_house_diagnostics` 控制正式流程与后台 PCG 诊断的隔离。
- `godot/tests/battle_view_smoke.gd`：战斗棋盘宽度、可读高度和手牌安全区契约。
- `godot/tests/capture_completion_pass.gd`、`capture_progression_ui.gd`：新增关闭后台主页和开播前预兆截图。

## 必须保持的不变量

- 正式名称只能是“织梦频道”；“山屋惊魂”仅可作为历史玩法参考，不能回到正式 UI。
- 正式流程不得显示 EXE hash、`3D BRIDGE`、KayKit、PCG 或 ROT 等实现术语；后台测试可显示必要诊断。
- 战斗棋盘底边不得进入设计坐标 `y=608` 起的手牌区；HUD 点击区和 3D 世界点击区必须继续分离。
- 本次改动只属于表现与输入布局，不得改变战斗规则、房间拓扑、PCG 连接账本和存档格式。
- `combat_ui_layout.tscn` 的五个区域节点不可重命名，运行时按名称读取矩形。

## 实际验证

- `input_intent_regression.gd`：PASS。
- `battle_view_smoke.gd`：PASS，覆盖 1024x640、1280x800、1600x900、1920x1080。
- `combat_input_regression.gd`：PASS。
- `card_system_regression.gd`：PASS。
- `kenney_formal_build_flow_regression.gd`：PASS。
- `home_video_regression.gd`：PASS。
- 可见渲染截图：`capture_completion_pass.gd`、`capture_kenney_formal_build_flow.gd`、`capture_combat_selection.gd`、`capture_progression_ui.gd` 均 PASS。
- 已人工检查 `artifacts/completion_00_home.png`、`completion_01_home_tests.png`、`kenney_formal_build_preview.png`、`progression_00_omen.png`、`progression_01_reward.png`、`combat_selection_fixed.png` 和 `completion_05_patrol_intent.png`，未见标题、按钮、卡面、HUD 或地图重叠。

## 遗留问题与建议

- 当前字体仍使用 Godot fallback font；后续正式字体需要同时验证中英文、数字和生僻字覆盖，不应只替换标题。
- 战斗卡插画仍来自现有概念资源，部分素材的饱和度和描边差异明显；后续统一资产时保持现有卡牌安全区和类型色编码。
- 目前响应式回归验证布局矩形，视觉截图以 1280x800 为主；新增移动端或更小窗口目标时应单独设计折叠方案。
