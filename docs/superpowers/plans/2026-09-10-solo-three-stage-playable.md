# 单人三阶段剧本抽选样片执行计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 先完成一间正式参考工坊示范房，再让玩家完整经历三次信物投入或弃权，抽出的房间经历实际改变第三阶段末尾的 PvE 破坏秀，并以玩具失去活力收束。

**Architecture:** 先把实体玩具质感测试中的 C 参考工坊提炼为正式表现契约，完成一间可从现实工坊切入电视梦境、并在梦醒后回到同一载体的示范房。其后复用正式探索、房间摆放、战斗奖励和大地图终局；以独立的三阶段控制器、经历账本、抽选器和终幕配置隔离新规则。新样片先从后台入口启动，使用独立存档；验证后再决定迁入默认新游戏，不重写现有渲染器或地图系统。

**Tech Stack:** Godot 4.7.x、GDScript、JSON、现有 SceneTree 回归脚本。

**Spec:** [主策划第 3.0 节与第 6 节](../../design/织梦频道_channel_dream_策划案与招标书.md)、[现实玩具与电视梦境](../../design/2026-09-10-现实玩具与电视梦境.md)、[未决登记](../../open-questions.md)。

状态：执行方案；尚未实现。日期：2026-09-10。本文的实验参数不是永久规则，不覆盖主策划中的未决选择。

## Global Constraints

- 单人只决定剧本，不创建虚拟参赛者、竞价排名或反派选角；终幕为 PvE。
- 恰好三个阶段，最终演出位于第三阶段末尾，不追加第四阶段。
- 候选只能来自玩家实际走过的地块；可弃权；唯一投注者不能锁定指定结局。
- 房间局内一次性、不重复；本轮按房间模板 ID 去重，不销毁局外资产。
- 信物评分与剧本概率分开，不能以总分直接充当抽选权重。
- 核心是演出与欢乐，不加入撤离经济、虚拟嘉宾或多人网络。
- 参考工坊是现实玩具层的表现基准，不增加工坊经营、材料加工、家具数值或制作小游戏。
- 首次正式推广只做一间示范房；中心底座、绿色切割垫、外围制作零件和后方工作环境需保持同一构图契约。
- C 参考工坊的测试开关不进入正式玩家界面；默认保留房间可读性，景深不得遮挡接口、门洞或角色占位。
- 保留当前房间资产、物理格、门洞与终局原地图；不回退到独立祭坛副本。
- 仅修改本任务文件；工作区已有美术、战斗与测试修改，执行前记录差异。测试使用独立存档，不清除用户正式进度。
- 不直接编辑 project.godot；本方案不需要更改项目设置。

## 一、前置交付：参考工坊正式化

在单人三阶段流程之前，先完成现实玩具层的一间示范房正式基线。图一只是视觉参考，不是额外的实现指令；正式基线提炼为以下必须可验收的关系：中心房间实体底座、外围切割垫与制作零件、后方工作环境、按部件分材质、拼装卡合与角色入场、进入电视梦境后保持房间标志性轮廓、梦醒后回到同一现实载体。

这一步的输出不是把 C 测试模式直接复制到所有房间，而是把它从“测试区样板”提升为“一间正式示范房的现实层表现契约”。完成前不得开始单人三阶段的终幕规则开发；否则无法判断玩家是在追求梦境本身，还是被临时测试画面吸引。

### Task 0：参考工坊示范房正式化

**Files:** 修改 `godot/scripts/toyhouse_tactile_lab.gd`、`godot/scripts/reference_workshop.gd`、`godot/scripts/toy_room_assembly.gd`、`godot/scripts/channel_3d.gd`、`godot/scripts/channel_3d_hud.gd`；创建 `godot/scripts/formal_workshop_profile.gd`、`godot/tests/formal_workshop_regression.gd`、`docs/design/正式参考工坊验收.md`；更新 `godot/README.md`。

**Interfaces:**

```gdscript
# FormalWorkshopProfile，RefCounted；只描述表现契约，不拥有战斗规则
static func for_room(room_id: String) -> Dictionary
# 返回 workshop_scene、room_presentation、material_families、camera、lighting、assembly、logic_guards
```

- [ ] 先记录当前工作区差异，确认图一对应的 C 参考工坊代码、回归和截图仍存在；运行现有 `toyhouse_tactile_lab_regression.gd` 与 `formal_cartoon_assembly_regression.gd` 作为基线。此步只检查，不覆盖现有用户资源。
- [ ] 写 `formal_workshop_regression.gd` 的失败断言：示范房存在实体底座和中心房间；绿色切割垫、至少两类外围制作零件和后方工作物件存在；门洞、房间逻辑格和角色占位不被外围装饰改变；退出后存档、环境、景深与房间坐标恢复。
- [ ] 从 `reference_workshop.gd` 提取正式 Profile，固定第一间示范房的 room_id、底座尺寸、切割垫低对比网格、书本／胶带／零件盘／金属小件、深色后墙／蓝窗／货架／时钟／桌灯构图。装饰节点进入 `workshop_decor` 组，运行时不加入房间 `room_prop` 逻辑交互槽。
- [ ] 将 C 的材质分工写入 Profile：哑光塑料、涂装木材、布料、金属、纸张、陶瓷、玻璃、黏土；保留原贴图和孟菲斯配色，微表面细节低对比。材质覆盖必须是副本，退出或切换场景恢复原材质。
- [ ] 将工坊镜头、灯光、景深与拼装契约写入 Profile：中心房间占主要视野；默认景深关闭或弱化；旋转时仅让最近外墙让位，中心房间不重组；房间落件、卡合、迟到零件和角色入场只改视觉节点。
- [ ] 增加“工坊 → 电视梦境 → 工坊”的最小入口演示，复用同一 room_id 与标志性主家具；梦境投射可以夸张比例，但不能丢失房间轮廓。此入口使用隔离样片存档，不改变正式续玩存档。
- [ ] 跑新回归与现有测试，人工检查图一对应的中心构图、四个主要朝向、近中远缩放、拼装和梦醒返回；通过后提交 `feat: formalize reference workshop baseline`。只有此提交完成，才执行 Task 1。

## 二、本轮交付及范围

可玩入口：标题 → 后台测试 → 单人三阶段样片。

```text
现有开局与探索
 → 第 4 房完成及奖励结算后：第一次信物选择／弃权、抽片
 → 第 8 房完成及奖励结算后：第二次抽片
 → 第 12 房完成及奖励结算后：第三次抽片
 → 三份素材公开组成终幕节目单
 → 原地图 PvE 破坏秀
 → 玩具停止动作、片尾、本集来源回顾
```

计数沿用当前玄关为 1/12 的基线；4、8、12 只是测试节点。首轮不加阶段小 Boss，先验证阶段抽选对终幕的影响。两种自制房获取方式、配置牌组供应、完整电视订购与永久解锁均留在下一轮；本轮投入已有访问房间作为信物，不能宣称已完成局外工房闭环。

## 三、可直接执行的实验参数

全部写入新建 `godot/data/solo_stage_trial.json`，只在样片入口加载。

```json
{
  "schema_version": 1,
  "milestones": [4, 8, 12],
  "damage_weight_cap": 6,
  "nomination_boost": 2,
  "uniform_mix": 0.5,
  "nonfinal_recovery_ratio": 0.5,
  "draw_animation_seconds": 2.0,
  "wake_seconds": 4.0
}
```

- 候选为累计已访问且未曾被抽中的非玄关房间，以 instance_id 识别访问记录、以 room_id 限制新房重复。不要求必须胜利才能入选。
- 每阶段只提名一间候选房间，或弃权。输入锁定后不可反复刷结果。
- 原始权重 `w = 1 + min(本房实际损血, 6) / 2 + (被提名 ? 2 : 0)`。
- 最终概率 `p = 0.5 / N + 0.5 * w / sum(w)`。N≥2 时所有候选均有机会，提名不会必选；弃权沿用相同损血加权，只移除提名加成。这是实验选择。
- 每阶段正常应有至少两个候选。若不足，不虚构未访问房间、不静默必选：暂缓抽选，提示“再探索一间房，节目就能抽片”，允许继续扩建；第三阶段同样如此。
- 本轮“区域”先按房间实例统计；记录实际扣除生命的正值，格挡不计、治疗不冲减、不以战斗前后净血差代替。权重有上限，原始记录保留。
- 信物记录 `rarity_rank`（1—3）与 `difficulty_rank`（0—2）；实验分为 `2 * rarity_rank + difficulty_rank`，没有永久奖励或排行榜。默认非自制候选 rarity_rank=1，普通房难度0、普通战斗1、精英2；依据 encounter_tier 优先、kind 次之。难度不是实际受伤量。
- 普通房战败只在样片中按一次事故完成该房，恢复至最大生命的50%（向上取整，至少1），不发胜利选牌；不能重刷同一遭遇。Boss 保持正常胜负。此为验证“中途不直接死亡”的临时口径。

## 四、文件与接口

新建：

| 文件 | 职责 |
| --- | --- |
| `godot/scripts/solo_stage_flow.gd` | 阶段门槛、待抽状态、最终配置与恢复 |
| `godot/scripts/dream_room_ledger.gd` | 访问、损血、已选素材与信物分数 |
| `godot/scripts/dream_draw_rules.gd` | 纯函数概率计算和抽样 |
| `godot/scripts/dream_finale_profile.gd` | 三份素材到明确终幕规则的映射 |
| `godot/scripts/dream_stage_panel.gd` | 候选选择、概率预览、抽片与节目单 |
| `godot/scripts/dream_wake_presentation.gd` | 四秒收束与片尾来源回顾 |
| `godot/data/solo_stage_trial.json` | 样片参数 |

修改：`channel_3d.gd` 只作现有流程接线；`channel_3d_hud.gd` 增加后台入口及阶段面板挂载；`combat_rules.gd` 提供实际损血累计；`overworld_boss_rules.gd`、`overworld_boss_program.gd` 和 `overworld_boss_presentation.gd` 消费终幕配置；`run_save_repository.gd` 复用读写接口，原则上不改实现。

统一数据约定：

```gdscript
# RoomRecord（JSON 可序列化，不保存 Vector2i 或节点引用）
{"instance_id": "i1", "room_id": "kitchen", "name": "厨房",
 "kind": "combat", "encounter_tier": "beat", "room_size": 1,
 "visited": true, "hp_lost": 3, "rarity_rank": 1, "difficulty_rank": 1}
# DrawResult
{"stage": 1, "nomination_id": "i1", "selected_id": "i2",
 "probabilities": {"i1": 0.6, "i2": 0.4}, "material": {}}
```

## 五、实施任务（顺序执行）

### Task 1：三阶段状态与隔离存档

**Files:** 创建 `solo_stage_flow.gd`、参数 JSON、`godot/tests/solo_stage_flow_regression.gd`；修改 `channel_3d.gd`、`channel_3d_hud.gd`。

**Interfaces:**

```gdscript
# SoloStageFlow，RefCounted
func reset(seed_value: int, config: Dictionary) -> void
func due_stage(completed_count: int) -> int # 0=无待抽，1..3=阶段
func accept_result(result: Dictionary) -> bool # 只接收当前阶段一次
func snapshot() -> Dictionary
func restore(data: Dictionary) -> bool
# channel_3d.gd 新入口
func start_solo_stage_trial(seed_value: int = 0) -> void
```

- [ ] 记录 git 差异，确认计划列出的接线函数仍存在；运行下方基线测试。已有失败单独记录，先定位会阻断本轮的失败，不把无关美术改动纳入提交。
- [ ] 写测试并运行，先验证新类缺失／行为失败：

```gdscript
var flow = load("res://scripts/solo_stage_flow.gd").new()
flow.reset(1337, {"milestones": [4, 8, 12]})
assert(flow.due_stage(3) == 0)
assert(flow.due_stage(4) == 1)
assert(flow.accept_result({"stage": 1, "selected_id": "a"}))
assert(not flow.accept_result({"stage": 1, "selected_id": "b"}))
assert(flow.due_stage(8) == 2)
var restored = load("res://scripts/solo_stage_flow.gd").new()
assert(restored.restore(JSON.parse_string(JSON.stringify(flow.snapshot()))))
assert(restored.due_stage(8) == 2)
```

- [ ] 实现独立状态，保存 `version/stage/results/rng_state/pending_result`；随机状态用字符串保存再转 int，避免 JSON 浮点丢精度。stage 在接受结果后推进，第三份结果后只能进入终幕。
- [ ] 在 `_finish_reward()` 后统一检查阶段，覆盖战斗、静室、事件与跳过奖励；奖励未结束不弹抽选。`_complete_current_room()` 不再在样片第12房直接绕过抽选去 `_prepare_boss_ready()`。
- [ ] 后台启动时先指定 `user://solo_stage_trial_v1.json` 再初始化新局；正式游戏恢复原 repository。已有正式存档缺少 dream_stage 时保持旧流程；未知新版本拒绝载入并显示原因，不清档。
- [ ] `_save_run()` / `continue_saved_run()` 保存恢复新块；增加待抽、已抽未播、第三次结算的往返测试。新样片终局清理仅清理自己的存档。
- [ ] 跑本任务测试与原完整流程测试；按文件明确暂存后提交 `feat: add isolated solo three-stage flow`。

### Task 2：房间经历与中途事故

**Files:** 创建 `dream_room_ledger.gd`、`godot/tests/dream_room_ledger_regression.gd`；修改 `combat_rules.gd`、`channel_3d.gd`。

**Interfaces:**

```gdscript
# DreamRoomLedger，RefCounted
func visit(record: Dictionary) -> void
func record_hp_loss(instance_id: String, amount: int) -> void
func candidates(excluded_ids: Array[String]) -> Array[Dictionary]
func snapshot() -> Dictionary
func restore(data: Dictionary) -> bool
# CombatRules 新增累计量，每次 initialize 归零
var actual_hp_lost_total: int = 0
```

- [ ] 写失败测试：重复 visit 不重复候选；未访问和玄关不入池；三个物理格属于同一个实例只计一次；治疗不能抹去已受伤量。

```gdscript
var ledger = load("res://scripts/dream_room_ledger.gd").new()
ledger.visit({"instance_id": "a", "room_id": "kitchen", "visited": true})
ledger.visit({"instance_id": "a", "room_id": "kitchen", "visited": true})
ledger.record_hp_loss("a", 3)
ledger.record_hp_loss("a", -2)
assert(ledger.candidates([]).size() == 1)
assert(ledger.candidates([])[0].hp_lost == 3)
assert(ledger.candidates(["a"]).is_empty())
```

- [ ] 在 `_finish_enter_room()` 第一次访问处记录稳定实例与房间元数据。在实际生命损失位置累计 `min(maxi(hp_before, 0), resolved_damage)`，检查全部扣血路径，包括敌人命中与玩家自损；不解析 event_log 文本。
- [ ] `_after_combat_action()` 按累计量增量同步到当前房间，保存同步游标防止重复刷新计分；房外事件扣血按结算前后实际损失另计。Boss 不再影响已经确定的三份素材。
- [ ] 样片普通战败在 `return_from_combat()` 应用50%恢复、一次完成、无胜利选牌并继续阶段判断；原正式游戏分支保持原行为。新增真实致命攻击测试，确认过量伤害不多计、房间无法重复刷奖励、终局仍可失败。
- [ ] 以本局已放 room_id 过滤剩余候选，测试房间不重复且旋转不是新房；池耗尽时明确提示，不循环补回用过的房间。
- [ ] 跑本任务及原战斗、完整流程测试，通过后提交 `feat: record room experiences for dream draws`。

### Task 3：提名、弃权与可解释抽选

**Files:** 创建 `dream_draw_rules.gd`、`dream_stage_panel.gd`、`godot/tests/dream_draw_rules_regression.gd`、`godot/tests/dream_stage_panel_regression.gd`；修改主场景接线与 HUD。

**Interfaces:**

```gdscript
# DreamDrawRules 静态方法；返回 {instance_id: probability}
static func probabilities(records: Array[Dictionary], nomination_id: String, config: Dictionary) -> Dictionary
static func pick(probabilities: Dictionary, roll: float) -> String # roll in [0,1)
static func token_score(record: Dictionary) -> int
# DreamStagePanel，Control
signal submitted(nomination_id: String)
signal reveal_finished()
func show_candidates(stage: int, records: Array[Dictionary], probabilities: Dictionary) -> void
func reveal(result: Dictionary, seconds: float) -> void
```

- [ ] 写失败测试并运行：

```gdscript
var Rules = load("res://scripts/dream_draw_rules.gd")
var rows: Array[Dictionary] = [
 {"instance_id": "a", "hp_lost": 6}, {"instance_id": "b", "hp_lost": 0}]
var cfg = {"damage_weight_cap": 6, "nomination_boost": 2, "uniform_mix": 0.5}
var p: Dictionary = Rules.probabilities(rows, "a", cfg)
assert(p.a > p.b and p.a < 1.0 and p.b > 0.0)
assert(is_equal_approx(p.a + p.b, 1.0))
assert(Rules.pick(p, 0.0) == "a")
assert(Rules.pick(p, 0.999999) == "b")
assert(Rules.probabilities([rows[0]], "a", cfg).is_empty())
```

- [ ] 实现第二节概率公式。按 instance_id 排序后采样，roll 从独立 dream RNG 获取；候选不足、提名不在候选中时不消费随机数、不提交结果。
- [ ] 面板展示房间名称、缩略图／现有房间图、受伤经历、提名后百分比与本次信物分。按钮文案为“交给节目”和“本次弃权”，不显示竞价对手、金币排名。
- [ ] 点击提交后先确定并保存结果与 RNG 状态，再播2秒轮盘／抽片；跳过动画仅结束表现。重复点击、返回主页、动画中续玩均不得重新抽取。
- [ ] 抽中后显示一句有事实依据的回顾，如“节目选中了厨房：你在这里损失了3点生命”；stage 1/2 展示素材提示，stage 3 进入节目单。抽中的素材从后续池排除。
- [ ] 测试未访问房间永不出现、弃权可完成、概率仅随输入变化、分数修改不暗改概率、恢复保持同结果。小池执行确定性分位抽样，不用易抖动的随机通过阈值。
- [ ] 人工验证实际点击、返回、跳过和屏幕可读性，跑任务测试后提交 `feat: add solo dream nomination and draw panel`。

### Task 4：三份素材真正改变终幕

**Files:** 创建 `dream_finale_profile.gd`、`godot/tests/dream_finale_profile_regression.gd`、`godot/tests/dream_finale_rules_regression.gd`；修改 `overworld_boss_rules.gd`、`overworld_boss_program.gd`、`overworld_boss_presentation.gd`、主场景接线。

**Interfaces:**

```gdscript
static func compose(materials: Array[Dictionary]) -> Dictionary
# 返回 name + source_ids + route_rule + anchor_rule + climax_rule
# 在终局 initialize 的 rules 字典传入 dream_profile，并写入 initial 存档。
```

采用一套共享终局、三个独立二选一规则，共8个组合；只新增下列边界明确的行为，保留现有击杀／关锚双胜利、生命／播出双失败。

| 来源 | 判断 | 终幕规则 |
| --- | --- | --- |
| 第一份房间 | room_size ≥ 3 | `long_charge`：冲撞路径上限4格；其他规则不变 |
| 第一份房间 | room_size = 1 | `short_charge`：沿用2格冲撞 |
| 第二份房间 | kind = combat | `relay`：关闭锚点后额外获得1 AP，每锚仅一次 |
| 第二份房间 | 其他 | `breather`：关闭锚点后额外回复1生命，不超过最大生命 |
| 第三份房间 | kind = combat | `double_sweep`：以选中房间内可达格为优先目标，每第三回合的扫场影响该格及全部直接相邻格 |
| 第三份房间 | 其他 | `spotlight`：每第三回合保持单次攻击，但摄影取景优先落在第三份素材房间的可达格，沿用既有取景压力 |

两类新增范围都先预告再执行；冲撞不得穿门墙，扫场不能跨无连接空间。上述为低成本差异验证，不将这8个组合宣传为8个完整剧本。

- [ ] 写 compose 的失败测试：三份来源顺序影响对应维度；资料不足返回明确 error；例如：

```gdscript
var materials: Array[Dictionary] = [
 {"instance_id": "a", "room_size": 3},
 {"instance_id": "b", "kind": "combat"},
 {"instance_id": "c", "kind": "quiet"}]
var p = load("res://scripts/dream_finale_profile.gd").compose(materials)
assert(p.route_rule == "long_charge")
assert(p.anchor_rule == "relay")
assert(p.climax_rule == "spotlight")
assert(p.source_ids == ["a", "b", "c"])
```

- [ ] 实现 compose 与节目单：列出三个房间如何导致三项规则。样片使用固定现有 Boss 基础数值；替代旧 earlyCombat/lateCombat 选 Boss 的样片分支，正式旧模式不变。
- [ ] 在现有预告计划阶段生成新范围，执行仅消费同一份计划；保存 dream_profile，回放时恢复，不重新根据实时房间数据组合。
- [ ] 锚点奖励只在耐久从正值转为0时触发；每次关闭记录唯一事件，重播动画与 UI 刷新不重复奖励。无可达来源格时明确报错并留在节目单，不静默换房。
- [ ] 对全部8个组合跑规则测试：门洞连通、预告与实际受击格一致、AP／治疗上限、重复关闭不发奖、存档回放一致。至少用同一地图和起始牌组真实完成两种差异最大组合的通关路径，不强制设 outcome。
- [ ] 人工玩两种组合并录制短片：应能指出准备、走位或关锚顺序至少一处不同。通过后提交 `feat: compose dream finale rules from three rooms`。

### Task 5：颁奖式开场与玩具静止结尾

**Files:** 创建 `dream_wake_presentation.gd`、`godot/tests/dream_wake_regression.gd`；修改 HUD、终局表现与 `_finish_boss_combat()`。

**Interfaces:**

```gdscript
# DreamWakePresentation，Node
signal finished()
func play(player_node: Node3D, recap: Dictionary, seconds: float) -> void
func skip() -> void
```

- [ ] 写失败测试：skip 可重复调用但 finished 只发一次，完成后 input lock 解除；不生成输赢相反的回顾。
- [ ] 节目单到 Boss 入场以三张素材卡依次亮起、一道聚光灯和现有声音／动效建立“节目颁奖”的表现；没有参赛排名、领奖对手和反派选角按钮。
- [ ] 胜负确定后先持久保存 ending_pending 与真实 outcome。四秒内镜头拉回、角色停止动画并稳定落在地面；保留地图，不删除或摧毁用户资产。跳过直接到同一结局，缺失角色节点则直接显示片尾。
- [ ] 片尾分别表达“梦演到结尾”或“梦提前中断”，附三张素材及其真实受伤经历。最后确认返回后清理样片存档；中途退出回来仍显示相同结局，不重发信物分。
- [ ] 验证胜／败／跳过／退出恢复四条路径，检查角色静止、可读性和输入恢复，通过后提交 `feat: present dream finale and waking coda`。

### Task 6：完整试玩与交付

**Files:** 创建 `godot/tests/solo_three_stage_flow_regression.gd`、`docs/design/单人三阶段样片验收.md`；更新 `godot/README.md`、`godot/NEXT_PHASE_PLAN.md`。

- [ ] 端到端自动测试覆盖三次投入、三次弃权、候选不足延迟、阶段结果持久化、普通房失败继续、真实终局与结局恢复。状态流可模拟普通房结果，但必须明确区分真实战斗验证：

```gdscript
assert(game.solo_stage_flow.snapshot().results.size() == 3)
assert(game.combat.initial.rules.has("dream_profile"))
```

- [ ] 测试构造两个隔离仓库并保留路径变量，验证样片没有修改原仓库内容；另以只读方式记录真实正式存档哈希前后相同，不向真实正式存档写入哨兵：

```gdscript
var Repo = load("res://scripts/run_save_repository.gd")
var baseline_path := "user://solo_trial_formal_sentinel.json"
var trial_path := "user://solo_trial_test.json"
var baseline = Repo.new(baseline_path, "trial-test")
assert(baseline.write({"sentinel": 1}))
var before := FileAccess.get_sha256(baseline_path)
var trial = Repo.new(trial_path, "trial-test")
assert(trial.write({"dream_stage": {"stage": 2}}))
assert(baseline_path != trial_path)
assert(FileAccess.get_sha256(baseline_path) == before)
```
- [ ] 跑下面的回归集合，检查每项退出码与 failures 输出，不以“脚本跑完”代替断言通过。
- [ ] 人工至少完整玩两局，一局每次投入、一局每次弃权；记录房间耗时、阶段等待、选取理由、实际终幕区别、是否故意刷受伤，以及结尾感受。
- [ ] 邀请3—5名未参与设计的人玩样片：问“这次终幕为什么这样演”“你下次想投入什么”。记录原话，不把满意度自行换算成通过。
- [ ] 更新完成度文档，列出已实现／仅测试／未实现；仅在结果证实后勾选任务。最后提交 `docs: record solo three-stage trial results`，不自动推送或发布。

## 六、验证命令与交付检查

当前机器已确认引擎存在。每条分别执行；其他机器先定位 Godot 4.7.x，不照抄本机路径。

```powershell
& 'D:\godot\Godot_v4.7.1-stable_win64.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/complete_run_flow_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/overworld_boss_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/run_progression_save_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/layout_offer_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/exploration_anchors_regression.gd
```

新测试使用同一命令模板，逐个替换为任务指定文件名：solo_stage_flow_regression、dream_room_ledger_regression、dream_draw_rules_regression、dream_stage_panel_regression、dream_finale_profile_regression、dream_finale_rules_regression、dream_wake_regression、solo_three_stage_flow_regression（均 `.gd`）。每个 SceneTree 测试收集 failures 并以0/1退出；纯规则 assert 示例需包进该项目测试入口，不能直接当顶层脚本运行。

## 七、里程碑与下一步判定

| 里程碑 | 包含任务 | 可供检查的结果 |
| --- | --- | --- |
| 0：现实载体 | Task 0 | 一间正式示范房有工坊构图、材质、拼装、梦境投射和梦醒返回 |
| A：流程可走 | Task 1—2 | 三阶段能暂停与恢复，普通房事故不中断样片 |
| B：选择可信 | Task 3 | 看得懂候选与概率，投入／弃权都可抽片 |
| C：结果有差异 | Task 4 | 前面三份素材改变终幕实际操作 |
| D：完整一场梦 | Task 5—6 | 颁奖式破坏秀、玩具静止、完整回顾与试玩记录 |

A—D 顺序依赖，且必须先完成里程碑 0。粗估为工坊正式化 2—3 个专注开发工作日，随后三阶段样片 5—8 个专注开发工作日；前提是基线可运行、资产复用且终幕规则未暴露大规模重构。完成里程碑 0 后重新估时，不作为工期承诺。

验收重点：玩家能解释至少一项“房间经历→抽选→终幕规则”的因果，两种组合产生不同的实际选择，结尾能正常收束。不满足时先修选择与兑现的关系，不追加剧情数量。

样片成立后，下一轮接入一间真正的自建房与配置牌组供应，比较随时放置／随机抽取，再做电视订购与实体解锁；多人选角和网络开发另开计划。
