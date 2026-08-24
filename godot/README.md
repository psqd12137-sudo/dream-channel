# Channel Godot 4 Client
状态：正式客户端事实（核对日期：2026-08-16）。

这是《织梦频道》当前唯一正式开发主线。玩法规则、运行数据、交互、3D 表现和发布质量都在本目录落地并由 Godot 回归测试约束。`web/` 只保留为低成本玩法实验场；其中的行为不会自动成为正式规则，也不要求与 Godot UI 保持一致。

## 打开项目与场景

- Godot 项目：仓库内 `godot/project.godot`（以 git 仓库相对路径为准，两台开发机各自 clone 的绝对路径不同，不要再写死盘符）
- 当前 3D 主场景：`godot/channel_3d.tscn`
- 旧版 2D 对照场景：`godot/main.tscn` —— 仅保留作历史原型比对，**不要运行或在其上开发**

技术要求：

- 引擎：**Godot 4.7.x**（`config/features` 为 `4.7`；用 4.6 打开会告警且行为不受保证）
- `application/run/main_scene` 已设置为 `res://channel_3d.tscn`；编辑器里按 **F5** 运行项目主场景（F6 只运行当前打开的场景，若当前开着 `main.tscn` 就会看到旧原型）
- 启动示例（`<repo>` = clone 出的仓库根，`<godot>` = 本机 Godot 4.7.1 可执行文件）：

```powershell
<godot> --path "<repo>\godot" --editor
```

- **不要**双击仓库外层目录里的 `DreamChannel.exe`（那是 2025 年的 Unity 旧构建，与本仓库无关）
- Godot 开发以各自本机仓库为准，不依赖网络共享；项目内资源统一使用 `res://`，移动目录不影响内部引用。

## 历史 Web 参考快照

`data/exe_snapshot/` 保存了一份 2026-08-13 的 Web 内容导入快照，用于追溯早期玩法和兼容既有数据。它不是当前规则权威，也不应反向覆盖 Godot 中已测试的正式行为。对应的可执行文件是 `web/CabinSlice_织梦频道.exe`：

- 最后写入：2026-08-11 19:36:02 UTC
- 大小：37,446,144 bytes
- SHA-256：`EEC4C574CC227FB966D39265A31E25F4D6875557C6BB09BB771E6760CC11DC03`
- 本地运行形态：EXE 启动 Go HTTP 服务，页面位于 `http://127.0.0.1:17887/`

精确来源记录在 `data/exe_snapshot/source_manifest.json`。Godot 目前仍从本地快照读取部分内容；后续修改这些数据时以 Godot 需求为准，并同步增加相应测试。

## 当前正式玩法（核对日期：2026-08-15）

1. 正式主页以“织梦频道”为唯一产品名，提供“打开电视机”“新手教学”“接着看上集”、自定义种子播出和右上角可展开的后台测试入口；后台中的“房间资产地编”可直接进入完整 3D 地编工具，并由右上角“返回标题”回到主页。
2. 开局先从两张“行前预兆”中选择一张；玄关计入行程，初始进度为 `1/12`。
3. 在等距 3D 屋面点击黄色扩建格；每次抽三张隐藏类型的房间票根，旋转并严格匹配双边门。
4. 角色走进房间才揭示内容，完成事件或战斗后才增加行程。
5. 惊吓时间使用独立 3D 战斗网格；每回合固定获得 `5` 点行动力，不再投掷 `0/1/2` 速度骰，并包含手牌、图形化生命/韧性/敌人意图、伏击/视线、追击与格内陷阱。
6. 无视野怪物会搜索最后目击点 5 回合，之后持续巡视；蓝色编号显示逐格路线，敌方回合播放实际移动/攻击动画。
7. 战斗规则已支持任意数量 `N` 个敌人：每个敌人用稳定 `enemy_id` 管理独立状态，按出生/内容顺序依次行动；单体卡牌必须在多敌人场景中明确选择目标，群体、范围和随机目标牌会按实际受击敌人反馈。

当前 AI 边界：敌人使用确定性的优先级规则状态机，并新增回合级战术黑板；敌人可按配置或特性分为 `hunter`、`flanker`、`controller`，视线成立时预订互不重叠的攻击位，再由既有移动/攻击执行器完成行动。视线、埋伏、最后目击点、巡逻、寻路、传送门、陷阱、高差、诱饵和特性攻击仍保持兼容。集火、保护、撤退、动态编队、诱导玩家走位和跨回合战术记忆尚未实现。正式内容快照仍主要使用旧的单敌人字段，多敌人内容通过房间的 `enemies[]` 数组接入。多敌人基础重构记录在仓库根 `.omc/plans/multi-enemy-refactor-plan.md`。
7. 节目测试台现含最大地图战斗意图、横版跳跃收集、八数码拼图、3D 微缩搜物，以及直接复用正式黄色扩建格、票根选择、旋转与摆放规则的 Kenney 桌模 PCG 测试。

详细的已完成/待补齐矩阵见 `WEB_GODOT_PARITY.md`。
后续战斗节奏、固定微缩模型与主循环接入计划见 `NEXT_PHASE_PLAN.md`。

## Unity 动态效果基线

- 摆放房间：完整房间作为一个根节点翻转落位，沿用 Unity 的悬高 `0.65` 格、初始 `94%` 缩放、`0.25s` 二次缓出，并补一段 `0.12s` 轻微落地回弹；候选房间会随每次旋转按钮即时转到对应门向，即使连续快速点击也不会失步。
- 进入房间：莉莉按 Unity 的每格 `0.25s` 平滑移动，落脚使用 `0.12s` 收势。
- 进入战斗房：战场地块先从平面展开构建，随后玩家与怪物从两侧落入各自格位；演出期间锁定输入，完成后才允许操作。
- 未知揭示：角色抵达后才执行 `0.10s + 0.10s` 的双段翻面，翻面中点切换为房间正面；摆放动画不会提前泄露内容。
- 演出期间会锁定摆放、进入、结算和战斗输入。脚本导出项 `animation_duration_scale` 可在 Inspector 设为 `0`（测试即时完成）或大于 `1`（慢动作校验）。

## 3D 结构

- 根节点：`Node3D`
- 镜头：正交 `Camera3D`，通过 `SubViewportContainer` 只渲染在 HUD 安全区内
- 房间、墙、门边、桥、扩建格、角色、战斗格、障碍和陷阱：运行时生成的 `MeshInstance3D`
- UI：`CanvasLayer + Control`，只负责承载 Web 信息层和把点击转发给 3D 世界
- 玩法入口：`scripts/channel_3d.gd`
- UI 入口：`scripts/channel_3d_hud.gd`
- 战斗规则：`scripts/combat_rules.gd`
- 最新 Web 数据适配：`scripts/web_content_adapter.gd`

大地图与战斗地图镜头操作（2026-08-21 镜头系统）：

- 左键：移动、选择格子或放置卡牌
- 左键拖动大地图或战场空白：围绕当前观察目标做连续 360° 水平旋转，俯角固定；旋转保持当前缩放和平移，未超过 5px 时仍按普通地格点击处理
- 从底部拖动放置牌时会拉出目标箭头，箭头落到有效格并释放即可布置；拖到战场外会返回手牌，卡牌本体不会遮挡棋盘
- 鼠标悬停手牌：卡牌上浮放大，显示插画与完整一些的效果说明
- 放置牌再次点击、右键、`Esc` 或“取消选牌”：退出金色摆放模式并恢复绿色移动目标
- 中键拖动：平移地图（探索、房间摆放与战斗均可用）
- 鼠标滚轮：以指针位置为中心缩放
- 顶栏“地图复位/镜头复位”：恢复当前地图的默认角度和完整取景，并退出镜头跟随；扩建预览重建时会保留玩家当前旋转、缩放和平移

镜头自动化（详见 `scripts/channel_3d.gd` 相机系统分区与 `scripts/camera_follow_math.gd`）：

- 每次开局/读档进入场景播放**入场运镜**（由远至近，正交视野 2.4× 缓动收敛到适配视野）
- 普通进房保持全景，不强制摇镜头；玩家按 `C` 切换房间特写，或在战斗/事件结束回到探索时触发特写跟随。跟随只平移、不自动旋转；旋转始终由玩家拖动选择
- 玩家显示在**画幅偏下**（探索偏移 `HOUSE_CAMERA_FRAME_OFFSET=0.15`）：上方留出视野
- 拖动相机松手后延迟 1.5s **回位**到玩家正上方（探索）——只回位置，旋转与缩放保持玩家选择
- 战斗镜头**自始至终对准玩家与怪物直线中点的偏上区域**（`BATTLE_CAMERA_FRAME_OFFSET=0.12` 偏上对准），走格跟随速率与探索一致（3.4）；fit 尺寸已把偏移计入，偏上对准下全棋盘仍可见

战斗房的木地板与大地图使用同一 KayKit 规格，并保留长方形木板的真实比例；1/3/5 格 footprint 直接决定地板、纸板墙、门洞和转角，footprint 外的逻辑格显示为绿色切割垫板后台。蓝色编号圆点表示敌人路径，红色圆点与四角标记表示必伤格，金色角标表示卡牌目标；传送门只在地面保留紧凑的 `A/B` 端点。

当前战场不再用整块高立方体表示高低差：H1 优先选用与大地图房间一致的桌、床、沙发等宽面主题家具，其余 H1 合并为带支脚、斜撑和胶带的连续深木舞台；H2 只使用楼梯与木结构变体。灯、植物和窄装饰不再充当平台或整格阻挡。逻辑站立面与阻挡体仍保留但默认不可见，所以角色可以稳定站在资产顶部而不会看见调试立方体。玩家站上传送门格后仍可正常移动、出牌或结束回合，也可额外支付一次移动费用点击成对端点或右栏“穿门”按钮。敌人只有在寻路选择门边时穿门，强制位移落到门格仍会触发传送，出口已有单位也不阻挡穿门。盖屋时，所选房间会作为微缩预览直接出现在扩建格中，点击“旋转 90°”会实时旋转该预览及门位。

纸傀儡现与已采纳的 Web 规则一致：傀儡占据格子并成为敌人优先目标；敌人花费攻击行动力打掉它后，若还有剩余行动力会继续本回合；追逐傀儡途中踩中伤害陷阱会额外触发 `纸影连击 +1`。意图文案与场内纸片人模型会明确显示这次攻击由傀儡承受。

## CC0 房间微缩布景

本节列出的第三方包是当前 PCG、门墙剔除、占位密度和交互槽位的结构验证资产，不是《织梦频道》的最终主题。正式美术目标是“荒诞儿童玩具秀的实体微缩布景”：生活家具负责宜居和角色互动，纸板/黏土/毛毡材质与摄影棚装置负责节目身份，事件状态负责暴露失控内核。不得因资源包名称或默认贴图把项目收敛成传统地牢、写实豪宅或纯温馨小屋。

首轮家具形体以 [KayKit Furniture Bits](https://godotengine.org/asset-library/asset/2125) 为基础，固定上游提交 `96d5930`，保留 53 个运行时 GLTF、共享色板、许可证与来源说明；它提供一致的低模家具比例，但不是项目最终视觉身份。Quaternius 的 [Ultimate House Interior Pack](https://quaternius.com/packs/ultimatehomeinterior.html) 精选子集用于补充床、厨房电器、壁炉等类别，许可证同为 CC0 1.0。来源分别见 `assets/third_party/kaykit_furniture_bits/SOURCE.md` 与 `assets/quaternius/ultimate_house_interior/SOURCE.md`。

大地图房间壳体暂用 [KayKit Dungeon Pack](https://kaylousberg.itch.io/kaykit-dungeon-pack) 的 CC0 精选 GLB 验证低矮地板、薄墙、门洞、转角和楼梯。它被 `scenes/pcg_hand_layout_lab.tscn` 与正式摆房测试入口共用，来源、精选范围和原始许可见 `assets/third_party/kaykit_dungeon/SOURCE.md`；其中木石默认材质属于占位表现，不能作为最终美术锁。

[Kenney Mini Dungeon](https://kenney.nl/assets/mini-dungeon) 仍保留为战斗地图的柱子、可站立地形块与掩体候选；[Quaternius Ultimate Modular Ruins](https://quaternius.com/packs/ultimatemodularruins.html) 保留为废墟题材候选。二者不会再作为当前大地图房间壳体。

- `hall / west_wing / cellar / parlor` 对应计划中的长廊、西厢、地窖和会客室示范房。
- 客厅、厨房、书房、卧室与温室复用同一套可配置布景；未知房不会实例化家具，避免提前泄露内容。
- `scripts/room_art_registry.gd` 只决定模型、位置、旋转与微缩比例；门向、战斗格、房间规则和 Lili 身份资产保持独立。
- 模型丢失或未导入时会发出警告并保留原有程序白盒，不阻塞玩法。

### 房间表现验收

- 每房先用主家具建立可辨认的生活功能，再放小型点缀；不按格子均匀撒道具。
- 每房至少保留一处节目摄影棚证据，例如场记板、走位胶带、摄影灯、提词卡、假窗、布景支架或可见机关。
- 一个逻辑格允许多个“演员走位点”。家具的坐、靠、翻找、表演和躲藏槽位彼此独立，为后续多人占位保留稳定 ID。
- 角色进入房间只选择空闲交互槽，不允许通过实时避让推动家具或重新生成整房摆放。
- 家具和节目装置不加入连接账本，不封堵门洞、楼梯、开放通道、玩家出生点和建造接口。
- 正常播出与节目失控复用同一套房间拓扑；异常主要通过灯光、音频、字幕、动画与少量道具状态切换表现。

## 角色模型

战斗与大地图中的玩家使用项目方提供的莉莉黏土角色 FBX，包含 41 根骨骼、蒙皮和完整动作集；怪物暂用 Quaternius `Cute Animated Monsters Pack` 的 CC0 `Demon`。两者都通过 `data/presentation_manifest.json` 配置模型路径、比例和动画名称：

- 待机：莉莉循环 `preset_biped_idle`，怪物循环原模型的 `Idle`；逻辑占格不变
- 移动：房间行走和战斗逐格移动期间，莉莉播放 `preset_biped_walk`；角色根节点同时平滑移动并转向目标格，移动结束后保留最后朝向
- 攻击/受击：莉莉使用 `preset_biped_slash / preset_biped_afraid`，怪物使用 `Bite_InPlace / HitRecieve`
- 家具互动：坐下和休息使用 `preset_biped_sit`，工作使用 `preset_biped_chop`；没有专用动作时由表现层回退到待机
- 未揭示怪物仍使用原有暗色剪影，进入视野后才切换到 3D 模型

`scripts/character_presenter.gd` 保留原 2D 帧动画作为模型加载失败时的后备。以后替换或迭代正式 3D 角色只需更新清单中的 `model_path`、缩放、朝向和 `animation_map`，战斗规则与棋盘移动不需要重写。莉莉模型来源见 `assets/characters/lili_clay/SOURCE.md`，怪物来源与许可见 `assets/quaternius/animated_characters/SOURCE.md`。

## 手调战斗 UI

打开 `scenes/combat_ui_layout.tscn`。这个场景以 1280 × 800 的设计分辨率保存战斗 HUD 的五个布局区域：`IntentArea`（历史意图区，已停用）、`ActionArea`（右侧行动栏）、`HandArea`（底部手牌区）、`DeckArea`（抽牌堆）和 `DiscardArea`（弃牌堆）。在 2D 视图中选中节点，用移动工具拖动，或在 Inspector 的 `Layout / Transform` 修改 Position 与 Size，保存后主游戏会读取这些 Rect；不要重命名这五个节点。

当前战斗界面为**杀戮尖塔式**（2026-08-21）：

- 战斗棋盘占顶栏下全幅场景（`COMBAT_VIEW_RECT` 20,88,1244,540），**无边框、无蒙层**，与手牌无硬分隔
- 手牌沉到画布底部，静止只露出上半（约 104px），**鼠标悬停升起完整显示并放大**；卡牌固定宽度 120px、均匀重叠错落排布
- 敌人意图显示在 3D 敌人头顶 `Label3D`（billboard，类型配色：攻击红 / 追击橙 / 搜索蓝 / 巡逻青 / 埋伏品红；攻击含伤害数字）
- 玩家/敌人状态条悬浮棋盘顶角，ActionArea（速度/行动力）在右下，抽/弃牌堆在底部两角
- 卡牌使用约 `120 × 199` 的固定比例；悬浮牌最后绘制并上浮放大，边框、字体、内边距和插画使用同一倍率，插画采用等比例 `contain` 显示而不会被拉伸

进一步的视觉打磨需求见仓库根 `docs/battle_ui_polish_prompt.md`（交给 Codex 的审美优化提示词）。

### 手调全部房间

打开 `scenes/room_layout_lab.tscn`。这里以 6 × 4 编辑地图放置了完整的 24 个房间；已有布景的 `Hall / Parlor / WestWing / Cellar` 可作为参考，其余房间是等待布置的可编辑纸盒单元。选中一个房间，在其下添加或拖入 FBX；再选中家具，在 Inspector 的 `Transform > Position / Rotation / Scale` 调整，最后保存场景。

要让主游戏读取新家具，请把家具节点加入 `room_prop` 组（Node 面板的 Groups）。运行时会按房间 ID 复制该组中的直接子节点；因此布局场景是房间美术的唯一来源，而不是再去改 `room_art_registry.gd` 的硬编码坐标。金色短条是门洞禁区，单个房间的可用底盘约为 `3.05 × 3.05`，家具应保持在此范围内。

### 微缩箱庭美术对比

打开 `scenes/diorama_art_lab.tscn` 可以手调三组完全隔离的样板：`CurrentBaseline` 是现有软装与几何墙体，`KenneyMiniDungeon` 是桌面模型候选，`QuaterniusRuins` 是破损墙体、石拱门与资产高差候选。每个模型都是场景树里的真实节点，可直接在 Inspector 修改 Transform；这份场景不会被主游戏当作房间布局读取。

运行项目后，在标题页展开“后台测试”，点击“桌模扩建 PCG”进入大房间节奏实验。该入口暂时把客厅、厨房、温室、卧室、育儿室升为三格房，把后院升为五格地标；正式开局仍使用原房型表。A/B/C 单格场景仍可直接运行 `scenes/diorama_art_lab.tscn` 检查资产；其中 Modular Ruins 只保留为历史对比，不再用于当前 PCG 桌模方案。

### PCG 连片箱庭实验

`scenes/pcg_diorama_stitch_lab.tscn` 保留为自动 Seed 整体构图测试；玩家实际评审入口是标题页“后台测试 → 桌模扩建 PCG”。该入口直接复用 `explore/build` 交互，但启用隔离的 `large_room_mix_test_mode`：三选一按尺寸分桶，参考 `1,3,3,5,3,1,3,5,3,1,3,1` 的 12 房节奏，玄关后不连续推荐单格，并让同一多格房统一使用一种地板 finish。点击黄色扩建格、选择票根、旋转并摆放仍走真实 `room_rules`；实验过程不会写入正式存档，回到正式开局后房型覆盖和地板开关都会重置。

当前 PCG 壳体分为四层：KayKit Dungeon 只保留木地板与高差楼梯；墙、纸盒门扇和转角柱改为程序化涂漆纸板；KayKit Furniture Bits 与 Quaternius 提供生活家具；每个已揭示房间额外生成演员走位胶带，以及场记板、假窗或播出灯牌之一。Modular Ruins 与 Mini Dungeon 石墙不再进入正式大地图链路。

家具生成使用主题语义和构图评分：主家具先建立视觉焦点，support/clutter/wall-bound 只在门洞禁区与主通道外寻找候选；共线阵列、过度分散、单格拥挤和同模型重复会被惩罚，同一模型整房默认最多两件。KayKit、Quaternius 与 override 家具进入正式场景时会经过暖纸色、低金属度、高粗糙度的运行时材质归一，源模型与贴图不被修改。

- 固定用 `R00 · 1格 → R01 · 5格` 开场，直接证明先放一格房、再接五格房的组合；后续继续混合 3 格和其他 1/5 格形状。
- 同一房间的相邻单元删除内墙，地板连续铺设。
- 房间生成时使用的连接边变成 Kenney `wall-opening` 与 `gate`；后来偶然贴合但不连通的跨房边保留完整墙。
- 占用并集的外边界生成连续平整纸盒墙板、折边、接缝胶带、外侧支撑脚和纸盒转角柱；朝镜头一侧保留剖视开口。
- 关闭连接显示有门扇的纸盒门框；两侧房间均已访问后整件门组件消失，只保留不参与碰撞的低门槛提示。
- 第一个五格房作为整体抬高，而不是随机抬高单格；连接高低区时自动补楼梯。
- 家具按房型组合和 2–8 件预算确定性摆放；每个逻辑格提供四个稳定演员槽位，角色占位不会推动或重排家具。
- 每个已揭示房间确定性绑定一个地面走位标记和一个墙面节目装置；墙面装置随规范墙边剔除，不加入连接、寻路或战斗账本。
- `set_room_broadcast_glitch(room_index, active)` 可让同一房间在“正常播出 / 节目失控”间切换：仅改变走位标记和节目装置的倾斜、缩放与发光，不重建家具、不换房间拓扑。
- 每个房间拥有独立视觉根节点和编号；重建时按房间顺序整块落位，因此五格房会作为一个建筑整体出现，不会逐格散落。

实验室支持“换一个 Seed”整栋重建并重播逐房落位动画，也可切回 A/B/C 单格样板。它验证的是网格版“建筑化学”：拓扑拼接、连续轮廓、门洞、高差和装饰密度；并不等同于 Tiny Glade 的无网格程序化网格、曲墙、屋顶变形与材质融合。正式数据中的 `room_rules.placed` 已用独立 `instance_id` 区分每间房，并要求跨房接触面门对门；当前正式摆放动画也会同步落下一个多格房的全部格子。把实验室资产拼接器接到这份数据、补齐最终转角/屋顶/门窗变体后，才能替换正式大地图的占位美术。

### 正式地图手摆模拟

打开 `scenes/pcg_hand_layout_lab.tscn`，只编辑场景树 `Layout` 下的房间节点；不要移动自动生成的 `GeneratedMap`。初始样板按正式摆放顺序提供 `1→5→3→1→3→5→1` 七间房；该场景现在作为编辑器构图辅助，实际游戏内旋转与摆放效果请使用标题页“桌模扩建 PCG”。

1. 选中一个 `Layout/Rxx_*` 房间节点，使用 Godot 移动工具拖动 X/Z；生成器按 `1.55m` 为一格自动吸附到最近格。建议在编辑器顶部开启移动吸附并把步长设为 `1.55`。
2. 绕 Y 轴旋转房间；生成器按最接近的 `90°` 读取朝向。建议把旋转吸附设为 `90°`。
3. 在 Inspector 修改 `shape_id` 选择 `single / line3 / l3 / plus5 / t5 / p5 / stair5 / u5`，修改 `room_id` 作为房间实例标识，勾选 `elevated` 生成整房高台与连接楼梯。
4. 要增加房间，选中最后一个房间节点按 `Ctrl+D`，改成唯一 `room_id` 后拖到已有建筑旁边。`Layout` 的节点顺序就是模拟的正式摆放顺序；除第一间外，每间房会从与先前房间相邻的边中选择一个入口门洞，其余额外贴边保留分隔墙。
5. 红色标签表示重叠或没有连接到此前房间；消除红字后再运行场景查看整房落位动画。房间编号和错误标签只用于评审，正式接入可以关闭。

这份场景保存的是房间根节点的形状、位置、旋转和高差，不保存自动生成的墙地板节点，因此可以安全反复手摆。评审通过后，再让正式大地图的 `room_rules.placed` 生成同样的描述并复用这套拼接器。

### 1 / 3 / 5 格房间

当前地图已接入多格房间：1 格用于空房、恢复和简单战斗等节奏调节；3 格支持长条与 L 形，承载追逐、抓人和拼图；5 格使用十字、T、P、阶梯与 U 形，作为大型精英战斗。进入一个多格房的任意占用格都会进入同一房间事件，完成后移动到该房间其他格不会重复触发。完整分配与后续规则见 `ROOM_FOOTPRINT_DESIGN.md`。

房间占用形状与门型是两个独立维度：两个房间即使都使用 `line3`，也可能分别抽到 `end` 与 `+` 门型；只有房间、门型和旋转都相同，外门方向才会相同。运行时已经把门型解析成逐格世界边表 `open_edges`：每个开启方向只选择一个稳定的外沿门位，随房间旋转、落位并与邻房双向校验，不会再把同方向整排格子全部打开。

## 与 Unity 版的隔离

- 不包含也不修改 `Channel_Teil` Unity 工程。
- 没有复制 Unity 的 `.meta`、Prefab、Scene、Library、Package 或 Catalog。
- Godot 工程只复用玩法概念和 Web 数据；旧 2D 场景也被保留，便于比对。
- Unity 版仍是另一条实现路线；`godot/` 是与其隔离的 Godot 客户端。

## 自检

> 路径约定：`<godot>` = 本机 Godot 4.7.1 可执行文件（console 版可用），`<repo>` = 本机 clone 出的仓库根。
> 两台开发机的绝对路径不同，命令一律用相对路径 `--path "<repo>\godot"`。

```powershell
$g = "<godot>"; $p = "<repo>\godot"
$tests = @(
  "smoke_test", "latest_3d_smoke", "web_snapshot_smoke", "combat_mechanics_smoke",
  "battle_view_smoke", "camera_orbit_regression", "camera_dolly_follow_regression",
  "ui_hit_regression", "combat_input_regression", "input_intent_regression",
  "card_system_regression", "dynamic_effects_smoke", "quaternius_room_art_smoke",
  "room_footprint_regression", "multi_room_build_regression", "large_room_mix_lab_regression",
  "enemy_patrol_intent_regression", "enemy_vision_state_regression",
  "enemy_turn_animation_regression", "enemy_traits_regression", "shared_cell_regression",
  "enemy_archetype_presentation_regression", "turn_timing_regression",
  "multi_enemy_roster_regression", "multi_enemy_legacy_compat_regression",
  "multi_enemy_state_regression", "multi_enemy_turn_regression",
  "multi_enemy_pathing_regression", "multi_enemy_targeting_regression",
  "multi_enemy_presentation_regression",
  "completion_labs_smoke", "diorama_art_lab_smoke", "pcg_diorama_stitch_smoke",
  "pcg_hand_layout_lab_smoke", "portal_height_build_preview_regression",
  "presentation_animation_regression", "home_video_regression",
  "run_progression_save_regression", "kenney_formal_build_flow_regression",
  "formal_build_promoted_regression", "kaykit_asset_bounds_probe", "character_animation_lab_smoke"
)
foreach ($t in $tests) {
  & $g --headless --path $p --script "res://tests/$t.gd"
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $t" }
}
```

- `latest_3d_smoke.gd` 覆盖二选一预兆、三张票根、摆下后隐藏、进入后揭示、3D 房屋网格与 3D 战斗网格；`dynamic_effects_smoke.gd` 额外覆盖房间翻转悬落、角色移动、未知揭示与输入锁。
- `camera_dolly_follow_regression.gd` 覆盖开局由远至近运镜、普通进房保持全景、手动特写跟随（只平移不旋转）、松手延迟回位（保持玩家选择的旋转）、战斗镜头对准玩家-怪物中点偏上。
- `ui_hit_regression.gd` 覆盖按钮命中、phase 切换重排 world rect、全屏/分辨率切换后的布局与命中。
- 个别依赖 `user://` 写入的测试（如 `run_progression_save_regression`、`formal_build_promoted_regression`）在无用户目录写入权限的受限环境会失败，属环境限制；正常开发机可直接运行。

截图脚本会把视觉校验图写入本机 `artifacts/`；该目录与 `.godot/` 一样属于可再生成产物，不提交到仓库。`capture_completion_pass.gd` 同时覆盖关闭/展开后台测试的主页，`capture_progression_ui.gd` 覆盖预兆双卡和奖励三卡，`capture_combat_selection.gd` 覆盖战斗选牌状态，`capture_large_room_mix_lab.gd` 覆盖大房间票根、落位和进入后的统一地板效果。

## 近期改动（2026-08-21）

### 镜头系统：运镜、延迟跟随与松手回位

- 开局/读档进入场景播放**入场运镜**（由远至近，正交视野 2.4× 缓动收敛到适配视野，`CAMERA_INTRO_DURATION=1.35s`）。
- 普通进房保持全景；按 `C` 手动切换房间特写，或在战斗/事件结束回探索时才启用**延迟平滑跟随**（指数平滑，速率 `HOUSE_CAMERA_FOLLOW_RATE=3.4`）。跟随只改位置、**不自动旋转**，旋转始终由玩家拖动选择。
- 玩家显示在**画幅偏下**（`HOUSE_CAMERA_FRAME_OFFSET=0.15`），上方留出视野；战斗镜头**自始至终对准玩家与怪物直线中点的偏上区域**（`BATTLE_CAMERA_FRAME_OFFSET=0.12`），fit 已把偏移计入半径。
- 拖动相机松手后延迟 1.5s **回位**到玩家正上方：只回位置，旋转与缩放保持玩家选择。
- 修复：跟随/回位期间 `_set_house_camera` 不再把对准点重置为布局中心（建房、战斗返回时的镜头跳变）；“地图复位”同时退出跟随恢复全图。
- 共享数学（平滑因子、屏幕上方偏移）抽到 `scripts/camera_follow_math.gd`；house/battle 两套镜头分区维护。

### 战斗 UI 杀戮尖塔式改造

- 战斗棋盘占顶栏下全幅场景，**去掉边框与黑层**；手牌沉到画布底部、静止只露上半、悬停升起完整显示并放大（杀戮尖塔式）。
- 敌人意图移到 3D 敌人头顶 `Label3D`（billboard、类型配色、攻击含伤害数字）；玩家/敌人状态条悬浮棋盘顶角。
- 视觉打磨需求已整理为提示词：仓库根 `docs/battle_ui_polish_prompt.md`（可交给 Codex 执行）。

### UI 点击对应修复

- 根因：`sync_layout` 只在窗口 resize 时刷新，phase 切换（home→omen→explore/build/combat）后世界区矩形不同步，导致点击判定与实际渲染错位；现按 phase 变化自动重排，并新增 `ui_hit_regression.gd` 约束。

## 近期改动（2026-08-20）

### 正式 UI 视觉整理

- 主页标题统一为“织梦频道”，副标题和开局文案改为荒诞儿童玩具秀、纸盒微缩片场语义；EXE hash、`3D BRIDGE`、PCG/KayKit/ROT 等开发信息不再进入正式流程。
- 顶栏收至 72px，探索右栏按“正在播出 / 本集进度 / 随身预兆 / 导播记录”分层；PCG 诊断只在“桌模扩建 PCG”后台入口显示。
- 建造阶段改为地图下方全宽操作带，三张票根显示中文房型、门型和方向，并为旋转、摆放、取消保留独立命令区。
- 预兆、节目奖励和战斗手牌改为独立卡面层级；奖励卡区分新道具、常驻预兆和演员成长，战斗卡区分放置、预备、药物和技巧，并提供费用不足遮罩。
- `battle_view_smoke.gd` 约束战斗棋盘不侵入手牌安全区；视觉截图新增正式主页与开播预兆状态。

## 近期改动（2026-08-19）

### 主页 UI 复刻（Unity 版美术）

- 主页改为深紫电视节目风：循环播放主角形象的 **AI 播片动画**（源文件 `web/ai_media/menu_video.mp4`，转码副本 `assets/ui/menu_video.ogv`），由 `channel_3d.tscn` 的 `VideoStreamPlayer` + `channel_3d.gd::_configure_home_video()` / `_set_home_video()` 控制（进主页播放、进游戏停止、回主页恢复）。
- 主/次按钮使用 Unity 版胶囊按钮贴图（洋红「打开电视机」、青「新手教学/接着看上集」），来源 `assets/ui/unity_buttons/`。
- 保留「回到标题」与「节目测试台」功能。

### PCG 建造转正

- `kenney_build_lab_mode` 由实验开关（默认关闭）转为 **默认开启**：正式主游玩（开局/读档）全程使用 Kaykit/Kenney 桌模渲染房间（门洞、墙、地板、透视、移动悬浮），不再走旧几何桥路线。
- `_save_run()` 的「实验模式不存档」短路已移除，正式游玩正常存档/读档。
- 新增回归测试 `tests/formal_build_promoted_regression.gd`（开局→预兆→探索→扩建→存档→读档全程 Kenney composer）与 `tests/home_video_regression.gd`（主页视频显隐/循环）。

### 渲染器修复（编辑器崩溃）

- 项目渲染器从 `gl_compatibility`（OpenGL 3.3，与 NVIDIA 610.47 驱动冲突导致编辑器启动即崩溃 `0xc0000005`）改为默认 `forward_plus`（Vulkan）。`project.godot` 中不再强制 OpenGL。

### 标准约定

- **Web 是规则基准，Godot 是 3D 表现分支**：玩法核对以共享盘 `\\192.168.1.21\bytedance\Shared\new channel\web\releases\CabinSlice_织梦频道.exe` 的实际行为为准。
- **Godot 是本机权威开发主线**：所有 Godot 开发在本地 `G:\dream-channel\godot` 进行，不依赖网络共享。
