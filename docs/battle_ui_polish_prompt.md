# 战斗界面视觉打磨提示词（杀戮尖塔式 · 给 Codex）

> 用法：把本文件全文粘贴给 Codex（或作为附件引用），它会用 godot-mcp 连接运行中的 Godot
> 实例自查截图，并在保持功能不变的前提下做视觉打磨。

## 项目背景

- Godot 4.7 项目，入口 `godot/channel_3d.tscn`，主逻辑 `godot/scripts/channel_3d.gd`（战斗/镜头）与 `godot/scripts/channel_3d_hud.gd`（HUD 绘制与输入）
- 战斗布局矩形 marker：`godot/scenes/combat_ui_layout.tscn`（IntentArea / ActionArea / HandArea / DeckArea / DiscardArea）
- 自查方式：`get_game_screenshot` 截图对比；命令行验证 `Godot_v4.7.1-stable_win64.exe --headless --path godot --script res://tests/<test>.gd`

## 已实现的功能（务必保持，不要回退或改变行为）

1. 战斗棋盘占顶栏下全幅场景（`COMBAT_VIEW_RECT` 20,88,1244,540），**无边框、无蒙层**
2. 手牌为杀戮尖塔式：沉到画布底部，静止时只露出上半（约 104px），悬停时升起完整显示并放大（`_draw_combat_hud` 的 `exposed_height` / `base_y` / hover 逻辑）
3. 敌人意图显示在 3D 敌人头顶 Label3D（billboard，类型配色：攻击红 / 追击橙 / 搜索蓝 / 巡逻青 / 埋伏品红），见 `_add_battle_pawn` 的 `EnemyIntent`
4. 战斗镜头：默认、走格跟随、松手回位都对准玩家-怪物直线中点的偏上区域（偏下构图），跟随速率 3.4，拖动松手 1.5s 后回位且保持玩家选择的旋转
5. 玩家/敌人状态条悬浮棋盘顶角；ActionArea（速度/行动力）右下；抽牌堆/弃牌堆在底部两角

## 用户觉得"不是很好看"，请以审美角度逐项打磨（参考《杀戮尖塔》）

1. **手牌观感**：露出的上半部分是否够有"卡牌感"？卡面、卡名、能量圆点、悬停抬起的动效是否精致？重叠间距是否自然？可考虑：卡牌底部深色渐变承接、投影、悬停时轻微上浮与放大曲线。
2. **状态条**：玩家/敌人状态条（HP 条、护盾/韧性、预备）的配色与排版是否符合"温馨电视节目"整体风格？参考色板：纸色 PAPER `#f8e9c7`、墨色 INK `#171c25`、青 TEAL `#22aa9b`、金 GOLD `#f3a51f`、品红 MAGENTA `#d63b72`。是否过于生硬/呆板？
3. **敌人头顶意图**：Label3D 的字体大小、描边、颜色与场景比例是否协调？攻击数字是否醒目易读？
4. **ActionArea 面板**：右下角"速度 / 行动力"面板样式是否与整体协调？"结束回合"按钮的位置与形态是否顺手？
5. **抽/弃牌堆**：底部两角的牌堆表现是否直观？（数量、图标、位置）
6. **整体构图**：棋盘、手牌、状态条、意图之间的视觉层级是否清晰？是否仍有"硬分隔"的观感？画面底部是否需要一条细微的深色渐变来承接手牌、让手牌与场景自然衔接？

## 硬约束

- 只做视觉/表现层调整，不改游戏逻辑、数值、交互判定
- 手牌点击判定（`combat_card_rects`）、镜头回位/跟随逻辑、意图数据源不得改动
- 修改后必须全部跑通（headless）：`smoke_test`、`battle_view_smoke`、`card_system_regression`、`combat_input_regression`、`camera_dolly_follow_regression`、`camera_orbit_regression`、`ui_hit_regression`
- 每处改动用截图前后对比说明理由
