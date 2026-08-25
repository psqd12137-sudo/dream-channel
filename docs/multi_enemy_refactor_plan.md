# Dream Channel 多敌人战斗重构计划

> 状态：待外部实施（无视觉 AI 执行）；最终验收保留给 Codex 视觉与代码复核
> 范围：Godot/GDScript 战斗系统，不迁移语言，不重做玩法，不顺带清理资产导入文件
> 规则层目标：支持任意数量 `N` 个敌人；内容建议上限 8；压力测试 12
> 基线版本：以仓库文档指定的 Godot 4.7.1 与对应 export templates 为准

## 1. 目标与当前事实

本次不是"双敌人特判"，而是把现有单敌人战斗重构为以稳定 `enemy_id` 为核心的多敌人系统。两个敌人仅作为第一个集成测试；4、8、12 个敌人用于验证实现没有写死数量。

当前单敌人假设分布在以下边界：

- 战斗状态只有一份 `enemy_pos`、`enemy_hp`、韧性、视野、AI 与异常状态，见 `godot/scripts/combat_rules.gd:15-66`。
- `CombatRules.setup()` 只接受一个 `enemy: Dictionary`，见 `godot/scripts/combat_rules.gd:83`。
- 意图和回合入口均为单数 `preview_intent()`、`enemy_turn()`，见 `godot/scripts/combat_rules.gd:327`、`:409`。
- 击杀当前敌人会立即设置 `outcome = "victory"`，见 `godot/scripts/combat_rules.gd:934-955`。
- 战斗入口从房间读取单个 `room.enemy`，见 `godot/scripts/channel_3d.gd:1892-1900`。
- 表现层固定查找和生成名为 `Enemy` 的单节点，见 `godot/scripts/channel_3d.gd:1930`、`:2054`、`:3090`、`:3607`。
- HUD 只绘制一个敌人状态条和一个敌方意图，见 `godot/scripts/channel_3d_hud.gd:689-696`、`:856-871`。
- 内容适配器只生成一个 `enemy`，见 `godot/scripts/web_content_adapter.gd:48-68`、`:123`。

## 2. 必须遵守的约束

1. 保持 GDScript 和现有 Godot 场景结构；不得引入 C# 或语言迁移。
2. 不允许出现 `enemy_1`、`enemy_2`、`first_enemy`、`second_enemy` 等数量绑定的规则字段或分支。
3. 所有敌人运行时行为必须由稳定、非空、场内唯一的 `enemy_id` 定位。
4. 旧房间数据 `enemy + arena.enemy` 必须继续工作，并在加载边界转换成长度为 1 的标准敌人数组。
5. 单敌人房间的规则、数值、交互和画面行为必须保持兼容。
6. 第一版敌人按稳定顺序依次行动和播放动画，不实现同时行动。
7. 不新增战斗中断点存档。现有存档仍只恢复到受支持的非战斗阶段；不得借本次重构扩大存档范围。
8. 不修改或清理当前工作区已有 `.import`、`.uid`、贴图及模型变化；实施提交只包含本计划允许的源码、测试、文档和必要数据。
9. 无视觉 AI 不得自行宣布视觉验收通过，只能提交截图证据包和已知限制。

## 3. 目标架构

### 3.1 权威状态

新增 `godot/scripts/combat_enemy_state.gd`，作为单个敌人的唯一权威状态。至少包含：

- `id: String`
- `spawn_order: int`
- `pos: Vector2i`
- `hp / max_hp`
- `toughness / max_toughness`
- `damage / action_points / attack_cost`
- `name / tier / archetype / archetype_label / archetype_desc`
- `traits / trait_labels`
- `revealed / player_sees_enemy / sees_player`
- `blind_turns / last_seen / last_seen_age / patrol_goal`
- `ambush_active / ambush_idle_turns / ambush_note`
- `broken / execute_bonus_pending / crush_bonus_pending / stagger_pending`
- `just_portaled / beam_pending_cells / beam_pending_damage`
- `alive()` 与只读导出调试快照的方法

`CombatRules` 保留整场战斗状态，敌人集合采用：

```gdscript
var enemies: Dictionary = {}          # enemy_id -> CombatEnemyState
var enemy_order: Array[String] = []   # 确定性的出生/行动顺序
```

必须提供集中查询函数，业务代码不得自行遍历并重复实现判断：

```gdscript
func living_enemy_ids() -> Array[String]
func enemy_by_id(enemy_id: String) -> CombatEnemyState
func enemy_at(cell: Vector2i, living_only := true) -> CombatEnemyState
func occupied_enemy_cells(except_enemy_id := "") -> Dictionary
func all_enemies_defeated() -> bool
```

不得长期保留可写的旧字段 `enemy_hp`、`enemy_pos` 等作为第二份状态。过渡期如需兼容测试，只允许使用只读 accessor，并在最终阶段删除。

### 3.2 标准房间数据

加载后的内部格式统一为：

```json
{
  "enemies": [
    {
      "id": "guard_a",
      "spawn": [4, 1],
      "name": "守卫",
      "hp": 6,
      "archetype": "armor",
      "traits": []
    }
  ]
}
```

兼容规则：

- 新格式优先使用 `room.enemies[]`。
- 旧格式 `room.enemy` 与 `room.arena.enemy` 转换为一个元素。
- 缺失 ID 时按房间实例 ID、数组索引生成确定性 ID；同一房间同一种子必须得到相同 ID。
- 重复 ID、越界出生点、出生在墙内必须返回明确错误，不得静默覆盖。
- 不要求批量改写现有 `godot/data/**/*.json`。

标准化逻辑应集中在 `godot/scripts/web_content_adapter.gd` 或一个新的内容标准化模块中，不得同时散落在 UI、场景和规则层。

### 3.3 目标与卡牌契约

卡牌目标类型标准化为：

- `self`
- `cell`
- `single_enemy`
- `all_enemies`
- `area`
- `random_enemy`

单体伤害、韧性伤害和状态施加必须显式传入 `enemy_id`。随机目标必须使用战斗内已有的种子 RNG，不得使用非确定性全局随机数。

第一版保持既有牌的原始语义：原来自动指向唯一敌人的牌，在只有一个存活敌人时直接使用；存在多个合法目标时必须进入目标选择，不得默认打第一个敌人。

### 3.4 敌方回合和事件契约

新增或抽取 `godot/scripts/enemy_turn_scheduler.gd`。每个敌方阶段：

1. 复制当前 `living_enemy_ids()` 作为本阶段稳定队列。
2. 按 `enemy_order` 顺序处理。
3. 每个敌人行动前重新确认仍存活且可行动。
4. 当前敌人独立计算视野、意图、移动预算和攻击。
5. 阶段中新生成的敌人从下一敌方阶段开始行动。
6. 玩家死亡后立即停止队列；所有敌人死亡后立即停止残留事件并判定胜利。

所有敌人事件必须包含来源 ID：

```gdscript
{
    "actor_id": "guard_a",
    "target_id": "player",
    "kind": "move",
    "from": Vector2i.ZERO,
    "to": Vector2i.RIGHT,
    "damage": 0,
    "label": "追击"
}
```

涉及另一个敌人时增加 `target_enemy_id`。表现层不得通过节点名或当前位置反推事件来源。

### 3.5 占格、寻路与陷阱

- 活着的其他敌人所在格作为当前行动者的动态阻挡。
- 两个敌人不得结束在同一逻辑格。
- 路径在目标格被先行动敌人占据后必须重新计算；无路时产生带 `actor_id` 的 `wait` 事件。
- 第一版不实现敌人互相穿越或换位。
- 玩家继续允许进入敌人格，但 `hostile_pass_cost` 按目标格中敌人数计算；由于禁止敌人重叠，通常为 1。
- 传送门出口被其他敌人占用时，本次传送无效并重新选择行动，不能覆盖单位。
- 陷阱只作用于实际踩中的敌人；伤害、致盲、减速和传送奖励均写入该敌人状态。
- 诱饵仍是全场共享目标；每个敌人独立判断是否攻击它。

### 3.6 表现层与 HUD

战斗节点结构改为动态容器：

```text
BattleRoot
  Player
  Enemies
    guard_a
    watcher_b
```

`channel_3d.gd` 维护 `enemy_nodes: Dictionary`，键为 `enemy_id`。动画、受击反馈、意图图标和模型配置全部通过 ID 查找。

HUD 第一版要求：

- 屏幕只保留一个"当前关注敌人"的详细状态条。
- 提供紧凑的存活敌人列表；列表必须能容纳 8 个敌人而不覆盖手牌、结束回合按钮和棋盘安全区。
- 鼠标悬停或点击敌人会更新 `focused_enemy_id`。
- 每个已揭示敌人头顶显示自己的意图；隐藏敌人不得泄露具体属性和意图。
- 镜头默认框选玩家和全部已揭示、存活敌人；隐藏敌人不能通过镜头自动偏移泄露位置。

视觉布局由实施方完成到"功能可用并可截图"的程度，最终美观、遮挡和信息层级由 Codex 实机验收。

### 3.7 攻击意图与远程敌人可读性增量

攻击意图继续由 `CombatRules` 负责判定，但表现层每次刷新只消费一次全体快照：

```gdscript
func preview_all_intents() -> Dictionary
```

快照中的每个敌人至少区分 `path`、`impact_cells`、`coverage_cells`、`line_cells` 和 `range_origin`；旧的 `hurt` 字段在迁移期保留为兼容别名。预览和实际执行仍必须调用同一套 `_enemy_attack_plan()`，显示层不得重新实现射程或视线算法。

远程敌人的 AI 攻击位由规则层验证，候选位置必须满足该敌人的射程、最小距离和视线条件；不再把远程敌人强制规划到玩家四邻格。多敌人落在同一格威胁时，表现层保留多个来源，渲染优先级为：实际命中红色、移动路径蓝色、聚焦敌人射程淡青色、射线青色。

射程默认只展开当前关注敌人；测试窗口继续支持 `test_focused_enemy_id`，普通战斗支持悬停敌人聚焦。这样 8 个敌人同时存在时不会铺满同一层范围色，也不会隐藏多个攻击者对同一格的威胁。

## 4. 分阶段实施与提交边界

每阶段单独提交；当前阶段验收不通过不得进入下一阶段。不得把全项目格式化或 `.import` 重写混入提交。

### 阶段 A：基线与失败测试

允许修改：`godot/tests/`、本计划、必要测试数据。

任务：

1. 记录实际 Godot 版本；若不是 4.7.1，停止并报告，不能静默生成新导入结果。
2. 跑 `godot/README.md:209-224` 列出的现有回归，并保存原始输出。
3. 新增多敌人规则测试骨架，分别构造 1、2、4、8、12 个敌人。
4. 测试必须先证明当前实现无法满足多敌人契约，再开始生产代码。

出口条件：现有单敌人基线已记录；新测试失败原因明确是功能缺失而非测试语法错误。

### 阶段 B：数据标准化与 EnemyState

允许修改：`combat_enemy_state.gd`、`web_content_adapter.gd`、相关测试。

任务：实现 EnemyState、旧/新房间格式标准化、ID 校验和确定性顺序。此阶段不改变战斗画面。

出口条件：

- 旧格式生成恰好 1 个敌人。
- 新格式 1/2/8 个敌人的 ID、出生点和属性准确。
- 相同输入和种子产生相同顺序。
- 重复 ID、越界、墙内出生测试明确失败并提供可读错误。

### 阶段 C：规则层改为 N 敌人

允许修改：`combat_rules.gd`、`combat_enemy_state.gd`、规则测试。

任务：把 HP、韧性、异常、视野、AI 记忆、伤害和胜利条件迁入敌人对象；所有伤害入口按 ID 工作。

出口条件：

- 伤害一个敌人不会改变其他敌人状态。
- 击杀一个敌人后 `outcome` 仍为空。
- 最后一个敌人死亡时且仅此时 `outcome == "victory"`。
- 1 敌人基线测试结果与重构前一致。
- 生产代码不再直接读写旧单敌人状态字段。

### 阶段 D：调度、占格和确定性

允许修改：`enemy_turn_scheduler.gd`、`combat_rules.gd`、相关测试。

任务：实现顺序回合、动态阻挡、重算路径、传送门占用和逐敌人事件。

出口条件：

- 4 个敌人连续运行 20 个回合，无重叠、越界和死循环。
- 固定种子重复运行 3 次，最终状态和事件日志完全一致。
- 玩家在第二个敌人行动时死亡，后续敌人不再行动。
- 阶段中生成的新敌人在下一阶段才行动。
- 所有敌人事件均有有效 `actor_id`。

### 阶段 E：目标选择与卡牌效果

允许修改：`combat_rules.gd`、`channel_3d.gd` 的战斗输入部分、卡牌测试。

任务：实现目标类型、单体选敌、群体与区域解析；保持旧卡牌单敌人语义。

出口条件：

- 多敌人时单体牌不能在未选合法敌人的情况下消耗。
- 群体牌只影响存活敌人。
- 区域牌按格子范围命中，不受数组顺序影响。
- 随机敌人牌在固定种子下结果可重复。
- 牌造成的伤害反馈事件包含目标敌人 ID。

### 阶段 F：3D 表现、HUD、镜头

允许修改：`channel_3d.gd`、`channel_3d_hud.gd`、必要布局场景、表现回归和截图脚本。

任务：动态敌人节点、按 ID 动画、每敌人意图、关注敌人 HUD、镜头框选和隐藏敌人保密。

出口条件：

- 1、2、4、8 个敌人场景的节点数与存活敌人数一致。
- 任意敌人移动/攻击/受击时，仅对应节点播放动画。
- 死亡节点被移除或明确进入死亡状态，不能继续显示意图。
- 8 敌人 1280×800 截图中，核心 UI 矩形互不重叠。
- 隐藏敌人的位置、详细状态和具体意图不被 HUD 或镜头泄露。

### 阶段 G：兼容清理与完整回归

允许修改：上述战斗文件、测试、文档。禁止无关重构。

任务：删除临时兼容 accessor、更新 `godot/README.md` 数据契约和测试列表、运行全套回归、生成交付证据。

出口条件：

- `rg` 不再发现生产代码直接依赖旧可写字段 `enemy_pos`、`enemy_hp`、`enemy_revealed` 等；测试辅助代码除外但必须注明。
- 不存在固定 `get_node_or_null("Enemy")` 或唯一敌人节点假设。
- 旧数据无需人工改写即可运行。
- 全套既有 headless 回归通过；受环境限制的测试必须单独列出原始错误，不得记为通过。
- `git diff --check` 通过，提交中没有无关 `.import`、`.uid`、模型或贴图变化。

## 5. 必须新增的测试

建议文件名可调整，但覆盖内容不得减少：

- `godot/tests/multi_enemy_state_regression.gd`
  - ID 唯一性、状态隔离、1/2/8/12 数量。
- `godot/tests/multi_enemy_turn_regression.gd`
  - 稳定顺序、死亡跳过、玩家死亡中止、新增敌人延后行动。
- `godot/tests/multi_enemy_pathing_regression.gd`
  - 动态占格、窄通道、无路等待、传送门出口占用。
- `godot/tests/multi_enemy_targeting_regression.gd`
  - 单体、全体、区域、随机目标、陷阱和诱饵。
- `godot/tests/multi_enemy_visibility_regression.gd`
  - 每敌人独立视野、致盲、最后目击点、隐藏信息。
- `godot/tests/multi_enemy_presentation_regression.gd`
  - 节点映射、事件归属、意图归属、死亡移除、关注敌人。
- `godot/tests/multi_enemy_legacy_compat_regression.gd`
  - 旧房间格式与旧单敌人行为。
- `godot/tests/capture_multi_enemy_acceptance.gd`
  - 生成最终视觉证据包。

每个脚本必须输出唯一的 `CHANNEL_MULTI_ENEMY_*: PASS` 标志，并在任一断言失败时以非零结果或明确 `push_error` 结束。外层 runner 不得只因 Godot 环境警告而把已经输出 PASS 的脚本误判为失败。

## 6. 无视觉 AI 的证据包

实施方完成后必须提供：

1. `git status --short` 与按文件分类的变更清单。
2. 每阶段提交哈希及对应出口条件。
3. Godot 精确版本输出。
4. 全套测试命令、原始输出、PASS/FAIL 汇总；不得只给口头结论。
5. 固定 1280×800、同一种子生成以下 Vulkan 非 headless PNG：
   - `multi_enemy_01_single_baseline.png`
   - `multi_enemy_02_two_targeting.png`
   - `multi_enemy_03_four_intents.png`
   - `multi_enemy_04_eight_hud.png`
   - `multi_enemy_05_hidden_enemy.png`
   - `multi_enemy_06_enemy_death.png`
6. 每张截图对应的 seed、敌人配置、当前回合、关注敌人 ID。
7. 一份 `known-issues.md`，即使内容为"无"，也必须明确写出。

截图只证明"已生成证据"，不代表视觉通过。

## 7. 最终验收标准（由 Codex 执行）

### 7.1 代码与架构

- 权威敌人状态只有一份，按稳定 ID 访问。
- 生产规则不存在数量特判。
- 房间、规则、事件、表现、HUD 的 ID 契约一致。
- 旧格式兼容发生在加载边界，不污染核心规则。
- `CombatRules` 不承担 3D 节点或 HUD 职责。

### 7.2 功能

- 1、2、4、8 个敌人均可完成完整战斗。
- 12 个敌人压力场景运行 20 回合无崩溃、死锁、重叠或非确定性结果。
- 击杀部分敌人不提前胜利；全灭后只结算一次。
- 每个敌人的状态、AI、意图、动画和受击反馈相互隔离。
- 单体、群体、区域、随机、陷阱、诱饵、传送门均符合计划契约。

### 7.3 回归

- 现有单敌人测试和主流程无行为回退。
- 全套 headless 测试通过，环境问题与产品问题分开报告。
- Windows 与 macOS 使用相同 Godot 版本后，旧房间和新多敌人房间都能加载。

### 7.4 视觉实机验收

Codex 将实际查看截图或运行游戏检查：

- 2/4/8 敌人可辨认，模型、底座、意图没有严重遮挡。
- 当前目标和当前行动者在 1 秒内可识别。
- HUD 不覆盖手牌、棋盘、安全区和结束回合按钮。
- 镜头不会因为远处隐藏敌人泄露其位置。
- 受击、死亡和行动动画对应正确敌人。
- 1280×800 与项目支持的其他显示模式下均可操作。

任一视觉项失败，整体状态为"功能通过、视觉待修"，不得宣告完成。

## 8. 风险与缓解

| 风险 | 触发信号 | 缓解措施 |
|---|---|---|
| 新旧状态并存导致不同步 | 同一敌人出现两套 HP/位置 | 禁止双写；阶段 C 结束前删除可写旧字段 |
| 事件无法归属正确模型 | 动画永远落到第一个敌人 | 所有事件强制 `actor_id`，表现层仅按 ID 查找 |
| 多敌人寻路死锁 | 窄通道反复重算或循环 | 每敌人行动设置有限 guard；无路产生 wait |
| 隐藏敌人泄露 | 镜头偏移或 HUD 出现属性 | 镜头只纳入已揭示敌人；独立保密测试 |
| 单敌人回归 | 旧牌或旧房间不能操作 | 旧格式标准化和单敌人快照测试先行 |
| 无视觉 AI 误判完成 | 只报告测试 PASS | 强制截图证据；视觉结论保留给 Codex |
| 工作区污染 | 提交大量 `.import` | 每阶段检查 diff；发现无关资源变化立即停止交付 |

## 9. 非目标

- 不迁移到 C#。
- 不实现实时或同时敌方行动。
- 不实现敌人之间互相攻击、换位或穿越。
- 不新增战斗中途读档。
- 不重做全部战斗 UI 美术。
- 不批量迁移现有房间 JSON。
- 不借机重构房屋生成、资产编辑器、PCG 实验室等无关模块。

## 10. 交付判定

外部实施方的完成状态只能是"待 Codex 验收"。只有同时满足代码、功能、回归和视觉四组标准后，Codex 才能给出最终 `ACCEPTED`。若规则正确但截图或实机画面不合格，返回带具体截图与场景的整改清单，不回滚已通过的规则层。

---

## 实施记录（随阶段追加）

### 环境基线（阶段 A，2026-08-24）

- 仓库：`F:\GoDOt\Channel`，分支 `main`，基点提交 `820cbbc`。
- 计划基线要求 Godot 4.7.1；本机实际唯一安装为 `F:\GoDOt\Godot_v4.7.2-stable_win64.exe`（`4.7.2.stable.official.ed1daf0bf`）。
- 版本偏差已报告苏博子，指示"这个不管"，继续以 4.7.2 执行；该偏差记入最终 `known-issues.md`。
- 工作区在实施开始前已存在约 200 个 `.import` 与 `project.godot` 的未提交修改（疑似 4.7.2 打开过项目所致）；按约束 8 保持原样、不清理、不纳入实施提交。
- README 自检清单 35 个 headless 回归全部 exit 0（34 个输出 PASS 标志；`kaykit_asset_bounds_probe` 为无断言探测脚本，正常输出 KAYKIT_BOUNDS 数据）。原始输出存于 `godot/artifacts/multi_enemy_baseline/`（artifacts 目录不入库）。
