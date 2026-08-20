# 2026-08-20：Web 敌人特性、共格与模型迁移

状态：客户端事实

基线：`origin/main` 的 `9127af7`。本记录随普通敌人特性迁移提交一起入库。

## 本次完成

- `WebContentAdapter` 将 `pressure.json` 的 `roomTraits` 和 `traitLabels` 写入每个战斗房敌人配置，不再只复制原始 JSON。
- Godot 规则层实现 `faceShock / cornerCut / lunge / vault / trapAware / guardBreak / grab / relentless / slam / beam / flurry`。
- 攻击意图与执行共用攻击规划函数。突进、破防、2x2 砸地、跨回合蓄力激光和两段连击不会再由 HUD 与结算分别猜测。
- 蓄力激光保存锁定格：第一敌方回合只蓄力，下一敌方回合按原红格结算，玩家可在中间回合离开。
- `grab` 适配 Godot 现有回合时序：敌方回合开始时非保留手牌已经进入弃牌堆，因此优先从手牌、弃牌堆、牌库中的可偷药物移除，再回退到普通牌。
- 3D 战斗层增加突进、突脸、破防、砸地、激光蓄力/发射和多段字形及动作反馈。
- 玩家可支付额外 1 点行动力进入敌人格，再从另一侧离开；窄门不再被单个怪物永久堵死。共格时敌人仍能近战，3D 表现会在同一逻辑格内错开两枚棋子。
- `presentation_manifest.json` 新增五类普通敌人表现目录：`execute / armor / stagger / crush / wire` 分别使用 Alien、Yeti、Orc Skull、Mushroom King、Blue Demon。
- 五个模型来自 Quaternius Ultimate Monsters，按 CC0 入库；许可证和官方来源保存在资产目录，未知原型继续回退到原 `Demon.gltf`。

## 关键文件与接口

- `godot/scripts/web_content_adapter.gd`
  - `_scale_enemy(...)`：附加房间特性和词条显示名。
- `godot/scripts/combat_rules.gd`
  - `_enemy_attack_plan(...)`：攻击意图与执行共用的规则计划。
  - `_choose_enemy_step(...)`：包含避陷阱和攀高优先级的确定性移动选择。
  - `beam_pending_cells`：跨回合激光锁定格。
- `godot/scripts/channel_3d.gd`
  - 新敌方事件的格子字形与角色动作播放。
  - `_battle_actor_presentation(...)`：规则原型 ID 到表现目录的合并入口。
  - `_battle_pawn_world(...)`：共格时的纯视觉错位，不改变逻辑坐标。
- `godot/data/presentation_manifest.json`
  - `enemy_archetypes`：五种模型、缩放与动画映射。
- `godot/assets/third_party/quaternius_ultimate_monsters/`
  - 精选 glTF、导入贴图、CC0 许可证与来源说明。
- `godot/tests/enemy_traits_regression.gd`
  - 11 种词条、数据接入、意图/执行一致性回归。
- `godot/tests/shared_cell_regression.gd`
  - 额外费用、堵门穿行、共格攻击和棋子视觉错位。
- `godot/tests/enemy_archetype_presentation_regression.gd`
  - 五模型加载、动画映射、独立模型路径和未知原型回退。

## 必须保持的不变量

- `preview_intent()` 不得独立重写攻击判断；新攻击必须进入共享规划接口。
- 蓄力攻击锁定的是格子，不是玩家节点；玩家离开红格后必须能够躲避。
- 普通敌人默认仍为单段，只有 `flurry` 才能在行动力允许时打两段。
- `guardBreak` 只在敌人付得起额外行动力时发动；否则允许普通攻击。
- 家具、房间演员槽位、墙面剔除和 PCG 连接账本不进入普通战斗规则。
- 模型路径不得进入 `combat_rules.gd`；规则只暴露稳定的 `enemy_archetype`。

## 已执行验证

- `res://tests/enemy_traits_regression.gd`：通过，覆盖全部 11 种词条。
- `res://tests/shared_cell_regression.gd`：通过，覆盖堵门穿行与共格战斗。
- `res://tests/enemy_archetype_presentation_regression.gd`：通过，覆盖五模型与回退。
- `res://tests/capture_enemy_archetypes.gd`：正常渲染模式通过，五种轮廓与单格占地截图写入本地 `godot/artifacts/enemy_archetypes.png`（产物不提交）。
- `res://tests/combat_mechanics_smoke.gd`：通过。
- `res://tests/web_snapshot_smoke.gd`：通过。
- `res://tests/enemy_vision_state_regression.gd`：通过。
- `res://tests/enemy_patrol_intent_regression.gd`：通过。
- `res://tests/input_intent_regression.gd`：无错误。
- `res://tests/turn_timing_regression.gd`：无错误。
- `res://tests/enemy_turn_animation_regression.gd`：无错误。
- `res://tests/latest_3d_smoke.gd`：无错误。

## 下一阶段

- 新增 Boss 棋盘编译器，以房间实例 ID 聚合多格 footprint，并读取正式连接账本生成显式邻接图。
- 先完成频道宿主的信号锚、播出进度与阶段闭环，再接入其余六名 Boss Profile。
- 为普通敌人的攻击类型补独立音效和特效映射；继续保持表现目录与规则隔离。
