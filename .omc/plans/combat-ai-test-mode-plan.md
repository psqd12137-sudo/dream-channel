# Dream Channel 房间战斗 / 敌人 AI 测试模式计划

> 状态：已实施（代码、回归和文档已完成；截图脚本需图形环境执行）
> 范围：复用主菜单现有“后台测试 → 战斗意图实验”入口，升级为战斗与敌人 AI 专用测试台
> 不在范围：新增主菜单按钮、迁移语言、重做正式战斗规则、替换其他后台实验、清理 `.import` 或本地生成文件
> 基线：Godot/GDScript 主线；复用现有多敌人规则、战术黑板、正式战斗画面和 HUD

## 1. 目标

把当前只能直接进入固定 `hall` 战斗的“战斗意图实验”，升级成可反复使用的开发测试模式。测试者应能在不开始正式流程、不污染存档和奖励的前提下：

1. 选择房间战斗场景和敌人 AI 场景。
2. 使用固定种子重复同一场战斗。
3. 选择手动战斗或 AI 观察循环。
4. 查看每个敌人的感知、角色、状态、计划目标、预留攻击位和行动事件。
5. 一键重开当前场景或返回测试台选择其他场景。
6. 生成足够让无视觉 AI 提交、再由 Codex 做最终视觉验收的证据。

## 2. 当前事实

- 主菜单已经有“后台测试”开关和“战斗意图实验”按钮，绘制入口位于 `godot/scripts/channel_3d_hud.gd:445`、`:463-467`，点击分发位于 `godot/scripts/channel_3d_hud.gd:1287-1300`。本计划直接复用它，不新增主菜单入口。
- 当前战斗实验固定调用 `start_combat_lab("hall")`，见 `godot/scripts/channel_3d.gd:836`；它只替换起始手牌和提示语，没有场景选择、AI观察控制或测试结果摘要。
- 正式战斗统一经 `start_combat()` 创建 `CombatRules`、切换 `phase = "combat"` 并构建战场，见 `godot/scripts/channel_3d.gd:1900`。测试模式应继续复用这条生产链路，避免维护第二套战斗。
- 当前 `return_from_combat()` 会在胜利时结算房间与奖励、失败时清理正式存档，见 `godot/scripts/channel_3d.gd:2506`。测试战斗必须建立独立返回分支，不能进入这两条正式流程。
- 战术黑板已提供回合计划、角色解析和攻击位预留，见 `godot/scripts/enemy_ai_blackboard.gd:19`、`:33`、`:62`、`:73`、`:91`。
- `preview_intent()` 已输出 `ai_role`、`ai_state`、`ai_reason` 和 `tactical_goal`，见 `godot/scripts/combat_rules.gd:578-590`；敌人状态还可由 `debug_snapshot()` 导出，见 `godot/scripts/combat_enemy_state.gd:60`。
- 敌方回合入口、战术预览和单敌人执行分别位于 `godot/scripts/combat_rules.gd:676`、`:684`、`:690`，可以作为观察模式的权威调用边界。
- 现有多敌人与 AI 回归已经覆盖循环、寻路、视野、巡逻、表现和目标选择；新测试模式应复用这些规则，不把调试逻辑写入 `CombatRules`。

## 3. 产品形态

### 3.1 入口与导航

保持现有路径：

```text
主菜单
└─ 后台测试
   └─ 战斗意图实验  →  房间战斗 / AI 测试台
```

入口按钮可以在实施时改名为“战斗与 AI 测试”，但位置和展开逻辑保持不变。其他横版、拼图、搜物、PCG、角色动画和资产地编入口不迁移、不删除。

测试台使用独立阶段 `phase = "test_combat_menu"`。从测试台进入战斗时仍切到正式 `phase = "combat"`，但设置显式的 `test_combat_active` 会话标记。战斗结束、主动退出或重开都返回测试台，不返回正式房屋流程。

### 3.2 第一版页面布局

测试台只做三栏，避免变成通用编辑器：

| 区域 | 内容 | 第一版交互 |
|---|---|---|
| 左栏：测试场景 | 场景名、类别、敌人数、用途 | 单选场景 |
| 中栏：配置摘要 | 房间、种子、玩家生命、牌组、敌人角色与特性 | 种子可编辑；其余来自预设 |
| 右栏：启动方式 | 手动战斗、AI单步观察、AI连续观察 | 启动、返回标题 |

第一版不提供任意拖格、任意编辑敌人数值或运行时创建敌人。复杂自定义会让测试结果难以复现；需要新增情况时，通过版本控制中的场景预设增加。

### 3.3 测试战斗内叠层

测试战斗继续使用正式战斗 HUD，在右侧增加可收起的“AI 调试”叠层：

- 当前测试场景 ID、固定种子、回合数、运行方式。
- 当前关注敌人的 `enemy_id`、`behavior_role`、`ai_role`、`ai_state`、`ai_reason`。
- `sees_player`、`last_seen`、`tactical_goal`、`tactical_reserved_cell`、特性列表。
- 本回合小队计划摘要：每个存活敌人的角色、目标格、预留格。
- 最近一回合事件：移动、等待、攻击、激光、死亡及对应 `actor_id`。

战场表现增加可关闭的调试覆盖：

- 猎手、侧翼、控场使用三种固定颜色标识。
- 预留攻击位绘制空心角标，不替换正式意图颜色。
- 当前关注敌人与其目标格之间绘制细线或编号；隐藏敌人仍遵守正式可见性规则，除非显式打开“显示隐藏信息”。

## 4. 测试场景目录

新增 `godot/data/test_mode/combat_ai_scenarios.json`，由 `godot/scripts/combat_test_catalog.gd` 读取和校验。测试数据不混入正式房间快照。

建议第一批预设：

| ID | 名称 | 主要验证 | 配置要点 |
|---|---|---|---|
| `baseline_single` | 单敌人基线 | 正式旧行为兼容 | 1 名 hunter、无遮挡 |
| `squad_roles` | 三角色围攻 | 角色分工与攻击位预留 | hunter + flanker + controller |
| `vision_search` | 丢失视野 | 视线、最后目击点、搜索转巡逻 | 墙体遮挡、玩家可换边 |
| `ambush_release` | 埋伏释放 | 埋伏一拍后进入巡逻/追击 | `ambush = true` |
| `choke_four` | 四敌人窄口 | 动态阻挡、无路等待、不重叠 | 4 敌人、单格通道 |
| `portal_trap_height` | 门、陷阱与高差 | 传送门占用、陷阱、高差选位 | portal + trap + H1 |
| `hud_eight` | 八敌人压力 | HUD、关注切换、行动归属 | 8 敌人、较大房间 |

每个预设至少包含：

```json
{
  "id": "squad_roles",
  "name": "三角色围攻",
  "category": "ai",
  "description": "验证正面、侧翼和控场不会预订同一攻击位",
  "seed": 20260824,
  "room": {
    "id": "test_squad_roles",
    "name": "测试房：三角色围攻",
    "arena": {},
    "enemies": []
  },
  "run_rules": {"player_hp": 40, "base_energy": 5},
  "deck": ["jab", "guard", "brace", "fling"],
  "observer": {"max_rounds": 10, "player_script": "stationary"}
}
```

目录加载时必须拒绝：重复 ID、敌人重复 ID、出生点重叠、越界、墙内出生、无效角色、无效牌 ID和不存在的玩家脚本。

## 5. 运行模式

### 5.1 手动战斗

- 使用正式选牌、移动、结束回合、敌方动画和胜负规则。
- 允许展开 AI 调试叠层，但不自动推进。
- “重开场景”使用原种子和原预设重新创建战斗。
- “返回测试台”立即丢弃本次测试会话，不结算奖励、不写正式存档。

### 5.2 AI 单步观察

- 玩家回合提供“推进一轮”按钮。
- 测试控制器按预设玩家脚本执行合法玩家动作，然后调用现有 `end_combat_turn()`。
- 敌方动画完成并开始下一玩家回合后停止，等待下一次点击。
- 不允许在动画未结束时重复触发，继续使用现有 `animation_busy` 锁。

### 5.3 AI 连续观察

- 提供“开始 10 轮 / 暂停 / 单步 / 重置”控制。
- 每轮必须等待正式敌方动画和 `_after_combat_action()` 完成，禁止用循环同步调用跳过画面链路。
- 默认玩家生命由预设设置为可观察 10 轮的数值；不修改正式伤害结算，也不添加无敌分支。
- 第一版玩家脚本只有：`stationary`、`alternate_cells`、`safe_random_walk`。所有移动必须通过 `can_move_player()` / `move_player()` 等公开规则入口。
- 到达胜负、10 轮上限、重叠、越界、事件缺少 `actor_id` 或执行超时后自动暂停并生成摘要。

## 6. 代码结构与实施边界

### 6.1 新增文件

1. `godot/scripts/combat_test_catalog.gd`
   - 读取、标准化、校验测试预设。
   - 不访问正式存档。

2. `godot/scripts/combat_test_session.gd`
   - 保存当前预设、模式、轮数、暂停状态、最后事件和异常。
   - 驱动玩家脚本，但只调用正式公开战斗 API。
   - 生成只读测试摘要。

3. `godot/data/test_mode/combat_ai_scenarios.json`
   - 存放可复现预设，不存本地个人参数。

### 6.2 修改文件

1. `godot/scripts/channel_3d.gd`
   - 将 `start_combat_lab()` 从固定 `hall` 入口改为进入测试台。
   - 新增 `start_test_combat(scenario_id, mode)`、`restart_test_combat()`、`return_to_combat_test_menu()`。
   - `start_combat()` 继续作为唯一战斗创建入口；测试函数只负责组装隔离参数。
   - `return_from_combat()` 在 `test_combat_active` 时返回测试台，禁止奖励、进度与存档路径。
   - `go_home()` 必须清空测试会话、自动推进定时器和调试覆盖状态。

2. `godot/scripts/channel_3d_hud.gd`
   - 保留现有“后台测试”入口位置。
   - 将“战斗意图实验”改为“战斗与 AI 测试”。
   - 增加 `test_combat_menu` 页面、场景选择与运行模式按钮。
   - 在测试战斗内增加可收起的 AI 调试叠层和重开/返回按钮。
   - 输入优先级必须高于战场点击，避免点击调试面板时移动角色或出牌。

3. `godot/scripts/combat_rules.gd`
   - 不加入测试模式分支。
   - 如 UI 需要一次读取全队计划，只允许新增只读 `preview_all_tactical_plans()`，内部一次建立黑板并返回深拷贝；不加入自动推进、无敌或测试日志逻辑。

4. `godot/README.md` 与根 `README.md`
   - 更新后台测试入口说明、场景列表、观察模式边界、执行与截图命令。

### 6.3 明确禁止

- 不允许测试模式改写 `CombatRules` 的伤害、寻路、AI选择或胜负规则。
- 不允许复用正式 `run_progress`、奖励、房间完成状态或保存文件作为测试结果。
- 不允许把测试专用敌人写入正式 `data/exe_snapshot/`。
- 不允许通过节点名推断敌人；调试数据继续使用稳定 `enemy_id`。
- 不允许自动观察直接写 `enemy.pos` 或 `player_pos` 绕过规则。

## 7. 实施阶段

### 阶段 A：目录与隔离会话

任务：建立预设数据、目录校验和测试会话对象；先证明测试运行不会污染正式状态。

出口条件：

- 7 个基础预设全部通过目录校验。
- 任一非法预设返回包含场景 ID 和字段名的明确错误。
- 进入、胜利、失败、重开、返回后，正式存档内容与进入前字节一致。

### 阶段 B：复用现有入口的测试台

任务：把“后台测试 → 战斗意图实验”改为测试场景选择页。

出口条件：

- 主菜单按钮位置和其他后台入口不变。
- 进入测试台、选择场景、返回标题均可鼠标完成。
- 1280×800 下三栏没有文字截断或按钮重叠。

### 阶段 C：手动战斗闭环

任务：测试场景进入正式战斗、重开和返回测试台。

出口条件：

- 7 个预设都能进入可操作战斗。
- 胜利和失败均返回测试台，不发奖励、不推进集数、不清理正式存档。
- 相同场景和种子重开后，初始房间、牌序和敌人状态完全一致。

### 阶段 D：AI 单步与连续观察

任务：实现合法玩家脚本、单步、连续 10 轮、暂停和异常停止。

出口条件：

- `squad_roles` 连续 10 轮无敌人格重叠、越界或无效目标格。
- `choke_four` 无路时产生合法 `wait` 事件，不死循环。
- 每个敌人事件都带可解析的 `actor_id`。
- 暂停后不再增加回合；继续后从当前状态推进，重置后回到原种子初态。

### 阶段 E：AI 调试叠层与证据包

任务：显示全队计划、关注敌人详情、事件时间线和调试覆盖；补截图脚本。

出口条件：

- 三角色场景中能同时辨认 hunter、flanker、controller 及三个不同预留格。
- 切换关注敌人时，状态、原因、目标和事件来源同步更新。
- 关闭调试覆盖后，战斗画面恢复正式显示，不残留节点。
- 生成测试台、三角色战斗、视野搜索、八敌人压力四张截图。

## 8. 自动化测试

新增：

- `godot/tests/combat_test_catalog_regression.gd`
  - 合法目录、非法字段、重复 ID、越界和出生点冲突。
- `godot/tests/combat_test_entry_regression.gd`
  - 现有后台入口、测试台阶段、返回标题和其他入口不受影响。
- `godot/tests/combat_test_isolation_regression.gd`
  - 胜负、重开、返回均不修改正式存档、集数、牌库和房间状态。
- `godot/tests/combat_test_observer_regression.gd`
  - 三种玩家脚本、单步、暂停、10 轮上限和异常停止。
- `godot/tests/combat_test_ai_overlay_regression.gd`
  - 调试数据与 `enemy_id`、`preview_intent()`、`debug_snapshot()` 一致。
- `godot/tests/capture_combat_test_mode.gd`
  - 测试台和手动战斗截图。
- `godot/tests/capture_combat_ai_observer.gd`
  - 三角色、视野搜索和八敌人截图。

必须继续通过的现有回归：

- `enemy_ai_cycle_regression.gd`
- `enemy_ai_tactical_regression.gd`
- `enemy_patrol_intent_regression.gd`
- `enemy_vision_state_regression.gd`
- `multi_enemy_turn_regression.gd`
- `multi_enemy_pathing_regression.gd`
- `multi_enemy_presentation_regression.gd`
- `combat_input_regression.gd`
- `enemy_turn_animation_regression.gd`
- `completion_labs_smoke.gd`

## 9. 视觉验收

无头测试只证明规则与节点结构，不作为视觉通过依据。实施者提交以下证据，由 Codex 最终验收：

1. 1280×800 主菜单展开后台测试截图，证明现有入口未新增、未错位。
2. 1280×800 测试台完整截图，证明三栏可读、按钮不重叠。
3. 三角色场景截图，打开 AI 调试叠层和预留格覆盖。
4. 视野搜索场景在“看见玩家”和“失去视野”两个时刻的截图。
5. 八敌人场景截图，检查敌人列表、意图、调试面板和手牌安全区。
6. 1920×1080 至少复验测试台与八敌人场景，确认缩放后仍可操作。

每张截图同时记录：场景 ID、seed、回合、运行模式、关注敌人 ID。视觉结论只允许标为 `PASS / PASS WITH NOTES / FAIL`，并列出遮挡、截断、辨识度和输入命中问题。

## 10. 风险与缓解

| 风险 | 表现 | 缓解 |
|---|---|---|
| 测试战斗污染正式进度 | 测试胜利后发奖励或改存档 | 独立 `CombatTestSession`；`return_from_combat()` 首先检查测试会话；存档字节回归 |
| HUD 膨胀 | 战斗画面被调试字段覆盖 | 面板可收起；默认只显示选中敌人；全队计划用紧凑列表 |
| 意图与实际行动不一致 | UI 反复调用规划导致计划变化 | 新增一次性全队只读快照；同一回合使用相同 seed 和 plan round |
| 自动观察跳过动画锁 | 回合重入、状态错乱 | 等待 `_after_combat_action()` 和 `pending_player_turn`；设置超时即暂停 |
| 测试逻辑侵入规则层 | 正式战斗出现无敌或自动移动 | `CombatRules` 只允许只读计划 API；自动化放在测试会话层 |
| 预设逐渐失真 | 数据可启动但不再验证目标 | 每个预设带描述和机器可验收条件；目录回归与对应 AI 回归绑定 |
| 八敌人 UI 不可读 | 状态和手牌互相遮挡 | 1280×800、1920×1080 双分辨率截图门禁；必要时滚动而非缩小字体 |

## 11. 完成定义

满足以下条件才可宣布“基础测试模式完成”：

- 复用现有“后台测试 → 战斗意图实验”入口，没有新增主菜单按钮。
- 至少 7 个可复现战斗/AI预设，覆盖 1、3、4、8 名敌人。
- 手动、单步、连续观察三种模式可完成“进入 → 运行 → 暂停/胜负 → 重开/返回”的闭环。
- 测试战斗不修改正式存档、奖励、进度、房间完成状态和正式牌库。
- AI 面板能解释“谁、看见什么、处于什么状态、为什么选这个目标、实际做了什么”。
- 新增回归与列出的既有回归全部通过。
- 视觉证据包齐全，并由 Codex 完成最终视觉验收。

## 12. 推荐实施顺序

按 `A → B → C → D → E` 顺序执行。第一批提交只做 A/B/C，先得到可手动循环的隔离测试模式；第二批提交做 D/E，再加入自动观察与 AI 可解释性。这样即使自动观察尚未完成，房间战斗测试也已经可以稳定复用。
