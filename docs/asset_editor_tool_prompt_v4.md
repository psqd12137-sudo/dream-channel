# 地编工具 v4：Unity Gizmo + 角柱拉墙 + 放门剔墙 + 墙段端点编辑 · 给 Codex

> 状态：实施计划（2026-08-22，基于当前 v3/v4 现状做交互与墙体语义升级）
> 用法：把本文件全文粘贴给 Codex，让它按「执行步骤」逐条实施。
> 前置：当前仓库已是"纸板片场 + 语义墙图"现状，关键文件：
> - `godot/scripts/asset_editor_3d.gd`（~1723 行，交互主控）
> - `godot/scripts/asset_diorama_rules.gd`（规则：`CELL=1.55`、`WALL_HEIGHT=0.72`、`WALL_KIND_IDS=["cb_wall",...]`）
> - `godot/scripts/cardboard_shell_builder.gd`（`build_wall/build_doorway/build_junction/build_join/normalize_kind/wall_height_for_kind`）
> - `godot/scripts/room_shell_graph.gd`（语义墙图：run 归并、join、socket）
> - `godot/scenes/asset_editor_3d.tscn`、`godot/tests/asset_editor_smoke.gd`
> Codex 动手前必须通读这 5 个文件，理解现状再改。

## 1. 需求（用户已逐条确认，照此实现）

| # | 需求 | 用户拍板 |
|---|---|---|
| D1 | **Unity 式可视化工具按钮 + Gizmo** | 完整 Unity Gizmo 手柄：移动=三向箭头拖拽平移、旋转=旋转环拖拽转角度、缩放=角/边手柄拖拽缩放 |
| D2 | **缩放语义** | **保留三档（0.6/1.0/1.5）**，缩放 gizmo 不做连续自由缩放，而是三档切换（拖手柄或按钮在档位间跳变） |
| D3 | **从格子四角拉墙** | 起点/锚点=格子外轮廓的**角柱（四角交点）**，拖到其他角柱/点形成墙面；**仍限房间外轮廓**，一次可拖跨多格成连续墙带 |
| D4 | **放门剔除墙体** | **选中某段墙再放门**；门替换掉该段墙（挖掉中间墙体，显示门扉）；**门可单独选中/删除/移动，删除门后该段墙自动恢复为实体墙**；放门/拆门都进撤销栈 |
| D5 | **墙段端点可编辑** | 选中一段墙后，**两端角柱端点可单独拖动**（延长/缩短墙，或拖端点重新定向）；门放在墙的开口处 |

## 2. 现状与差距（对照表）

| 需求 | 现状 | 差距 |
|---|---|---|
| D1 移动/旋转/缩放 gizmo | 目前用 `E+拖动`旋转、`R`三档、左键拖动移动，**无 gizmo、无工具按钮** | 补移动/旋转/缩放三个工具按钮 + 三个 gizmo 手柄 |
| D2 缩放三档 | 已有 `_cycle_size_tier()`（R 键），幽灵/选中资产都有 `size_tier` | 从"键盘 R"改为"缩放 gizmo 拖手柄在三档间跳变"（档位语义不变） |
| D3 角柱拉墙 | 画墙起点=`_snap_to_room_boundary`（任意边界点），`_begin_wall_drag` | 起点**只吸附到外轮廓角柱点**（四角交点），作为锚点拉出 |
| D4 放门剔墙 | 门=画一段 `cb_doorway` 墙，与相邻墙并列，**不是"挖洞"** | 改为**选中实体墙段→放门→该段替换成门洞**；门独立可编辑 |
| D5 墙段端点编辑 | 墙段端点固定，只能整段移动/删除 | 补**两端角柱端点可拖**（延长/缩短/重定向） |

## 3. 设计与实现规格

### 3.1 工具模式 + Gizmo（D1、D2）

**新增工具状态机**：`tool_mode: String` ∈ `{"select", "move", "rotate", "scale"}`。

- **ToolBar UI**（`UI/ToolBar`，HBox）：3 个 ToolButton（可切换 toggle），带图标：
  - 移动 `ToolMove`、旋转 `ToolRotate`、缩放 `ToolScale`；默认 `select`（选择）。
  - 点选切换 `tool_mode`；再点当前工具回到 `select`。
- **gizmo 手柄**（`ui_gizmo.gd` 或 `asset_editor_3d.gd` 内实现，建议独立脚本+场景）：
  - **移动**：3 个方向箭头（X 红 / Y 绿 / Z 蓝）`MeshInstance3D` + 拖拽命中判定；拖箭头→资产沿该轴移动。
  - **旋转**：水平旋转环（TorusMesh，Y 轴环）+ 命中判定；拖环→资产绕 Y 轴旋转任意角度。
  - **缩放**：三档语义下，缩放 gizmo 用**一个三档刻度条/角手柄**，拖手柄→在 `0.6/1.0/1.5` 间跳变（吸附到档位），不做连续缩放。
- **Gizmo 显隐**：仅当 `selection != null` 且 `tool_mode` 为对应模式时显示，跟随选中资产位置。
- **输入分流**：`_unhandled_input` 优先级改为——先在 gizmo 上做命中检测（`_gizmo_hit(event)`），命中则交给 gizmo 处理；否则走原有逻辑（放置/选中/画墙）。
- **半墙/门/转角等结构件**：均可被抓着 gizmo 操作（与普通资产一致），但由于墙**限外轮廓**，移动/旋转/缩放这类结构件禁用 gizmo（或仅在 D5 的"端点拖拽"下允许），避免墙飞出边界。**普通家具资产**用完整 gizmo。

> 说明：D2 是"保留三档"，所以缩放 gizmo 拖手柄是在档间跳变 + 显示当前档位（`0.6 / 1.0 / 1.5` 高亮），不是连续缩放。做到这一步即可，不要做成连续。

### 3.2 角柱拉墙（D3）

**房间外轮廓角柱点**：由 `Rules.room_boundary_edges(room_cells)` 求出所有边界线段的**端点集合**，
去重后即外轮廓角柱列表 `corner_anchors: Array[Vector3]`（含每个角的位置与所属格）。

- **画墙入口**：墙工具模式下，`_begin_wall_drag` 改为——鼠标按下点**只吸附到最近的角柱点**
  （`_snap_to_corner_anchor(point) -> Dictionary`），若不在任何角柱邻近（距离 > 0.3）则拒绝开始。
- **锚点显示**：进入画墙模式时，所有角柱点显示小 `CSGBox` 或 `MeshInstance3D` 圆点（金 `#f3a51f`，
  命名 `CornerAnchor_*`），提示"从这里拉墙"。
- **拖出**：从锚点 A 拖到 B（B 也吸附到角柱点），`_draw_wall` 沿 A→B 路径（仍走 `_wall_segments_for_drag`，
  沿外轮廓）生成连续墙带。B 不必是相邻角，可跨多格——`RoomShellGraph` 会归并为同一 `run_id`。
- **轴向约束**：同 v3，沿外轮廓水平/垂直；`_wall_axis_from_drag` 决定方向。
- **取消**：`Esc` 或拖回起点 / 松手时 A==B → 不生成。

### 3.3 放门剔墙 + 门独立编辑（D4）

**放门**：
- 选中一段**实体墙**（`tool_mode=select` 时点选墙段），出现上下文；点门工具 `/ 快捷键`（如 `G` 或门工具按钮）
  → 对选中墙段放门。
- **实现**：把该墙段替换为 `cb_doorway` 墙段——即删除实体墙，在原位置生成门洞段（`build_doorway`），
  AABB/meta 更新，`RoomShellGraph` 重新编译，进撤销栈。
- **视觉**：门洞挖掉中间墙（两侧保留 Side 墙 + Header 顶部 + DoorLeaf 门扇 + DoorCue 金色点），
  中间墙体被"剔除"，可透过门看到屋外。

**门独立编辑**：
- 门洞段作为独立节点，可**选中/删除/移动/旋转/撤销**（与普通墙段同待遇）。
- **删除门 → 恢复实体墙**：删除 `cb_doorway` 段时，自动在原位置生成一段实体 `cb_wall`
  （长度与原门段相同、沿同一外轮廓边界）。这是"挖掉又补回"的语义。
- **移动门 → 移动门洞位置**：门可在同一条外轮廓边界上左右滑动（沿墙轴吸附格边界），
  不允许滑出房间外轮廓。
- 全部操作进撤销栈。

### 3.4 墙段端点编辑（D5）

- 选中一段墙后，墙段**两端显示角柱端点手柄**（`Endpoint_*`，可拖拽）。
- 拖一端端点：
  - **沿墙轴**：延长/缩短墙（端点吸附格边界；墙段数量随长度增减，`RoomShellGraph` 重新归并 run）。
  - **拖到垂直方向**：重定向该端，产生 L 形转向（自动在转弯处生成转角柱 `build_junction`）。
- 若该墙段是门洞段，端点编辑同理（门在开口内，端点移动改变门段长度，门扇随之调整）。
- 端点拖拽也进撤销栈。

### 3.5 视觉与层叠

- 角柱锚点、端点手柄、gizmo 手柄都放在一个**编辑器覆盖层**（`EditorOverlay`，Node3D）下，
  不参与资产 AABB、不参与模板序列化、不投阴影。
- 选中高亮（SelectionRing 金色）与 gizmo 共存：选中显示环 + 对应工具 gizmo。
- 家具资产 gizmo 是完整三向；墙/门/结构件只允许"移动(沿轴)+端点拖拽"，旋转/缩放 gizmo 隐藏。

## 4. 文件改动清单

| 文件 | 动作 |
|---|---|
| `godot/scripts/gizmo_3d.gd` | **新增**：移动箭头/旋转环/三档缩放手柄的构建与命中判定、gizmo 显隐/跟随 |
| `godot/scripts/gizmo_3d.tscn` | **新增**：gizmo 场景（MoveArrows/RotateRing/ScaleHandle，材质红绿蓝/金） |
| `godot/scripts/asset_editor_3d.gd` | **改**：`tool_mode` 状态机、gizmo 输入分流、`_begin_wall_drag` 吸附角柱、放门/拆门逻辑、墙段端点拖拽 |
| `godot/scripts/asset_diorama_rules.gd` | **改**：新增 `corner_anchors(cells)`、`snap_to_corner_anchor(point)`；门恢复墙的辅助函数 |
| `godot/scenes/asset_editor_3d.tscn` | **改**：新增 `UI/ToolBar`（3 个 ToolButton + 门工具按钮）、`EditorOverlay` 容器、帮助文案 |
| `godot/scripts/room_shell_graph.gd` | **改**：门段替换墙段、门删除恢复墙的图重编译 |
| `godot/tests/asset_editor_smoke.gd` | **改**：新增 gizmo/角柱拉墙/放门剔墙/端点编辑测试 |

## 5. 测试规格

### 5.1 规则单测
1. `corner_anchors([[0,0]])` → 4 个角点 `(0,0 / CELL,0 / 0,CELL / CELL,CELL)`
2. `corner_anchors` 对 L3/line3 去重后数量正确（相邻角共享去重）
3. `snap_to_corner_anchor((0.1,0,0.1))` → `(0,0,0)`；远离角柱 → 返回空
4. 放门剔墙：`replace_wall_with_door(wall)` 后原墙删除、门洞段生成、`get_meta("is_door")==true`
5. 删门恢复墙：`remove_door(door)` → 原位置生成实体墙、`is_door` 消失

### 5.2 场景级
1. 画墙起点只能吸附角柱：`_begin_wall_drag` 在非角柱点 → 拒绝；在角柱点 → 成功
2. 从角柱 A 拖到角柱 B（跨 3 格）→ Walls 生成连续墙带、`run_id` 相同、`RoomShellGraph` 归并 1 条 run
3. 选中实体墙 → 放门 → Walls 该段替换成 Doorway、中间墙体移除、`is_door` true
4. 删除门 → Walls 该位置恢复实体墙、`is_door` 消失
5. 墙段端点拖拽：拖一端 → 墙长变化（Walls 段数增减）；拖到垂直方向 → 出现 L 转角
6. Gizmo：`_gizmo_hit` 命中移动箭头 → 资产位置平移；命中旋转环 → yaw 变化；缩放手柄 → 档位跳变（0.6/1.0/1.5）
7. `tool_mode` 切换：move→rotate→scale→select 状态正确；非 select 时 gizmo 显隐正确

### 5.3 保留回归
v3/v4 已有的纸板墙/模板/撤销/相机测试全部保留并更新到新函数名。

## 6. Codex 执行步骤

1. 读本文件 + 5 个前置文件（asset_editor_3d.gd / asset_diorama_rules.gd / cardboard_shell_builder.gd / room_shell_graph.gd / asset_editor_3d.tscn）。
2. 新建 `gizmo_3d.gd` + `gizmo_3d.tscn`（§3.1），先跑规则单测。
3. 改 `asset_diorama_rules.gd`：角柱锚点、吸附函数、门/墙替换函数（§3.2/3.3）。
4. 改 `asset_editor_3d.gd`：tool_mode 状态机、gizmo 输入分流、角柱画墙、放门/拆门、端点拖拽（§3.1–3.4）。
5. 改 `asset_editor_3d.tscn`：ToolBar、EditorOverlay、帮助文案。
6. 改 `room_shell_graph.gd`：门替换/恢复的重编译。
7. 改 `asset_editor_smoke.gd`：§5 测试。
8. headless 跑测试：`D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path G:\dream-channel\godot --script res://tests/asset_editor_smoke.gd`（若 headless 崩，先退出正在运行的 Godot GUI 再跑；崩溃是环境/并发问题）。
9. godot-mcp 连运行 Godot，F6 运行 `asset_editor_3d.tscn`，截图验收：
   - 三个工具按钮 + 移动箭头/旋转环/缩放手柄 gizmo
   - 角柱锚点高亮 + 从角柱拉出跨格墙带
   - 选中实体墙放门 → 墙体剔除显示门扉
   - 门单独选中/删除/移动；删除门恢复实体墙
   - 墙段端点拖动延长/重定向出 L 转角
10. 跑正式回归（smoke_test / pcg_diorama_stitch_smoke）。
11. 按规范提交（`feat(godot):`）。示例：`feat(godot): 地编工具 v4——Unity Gizmo、角柱拉墙、放门剔墙与独立编辑、墙段端点编辑`。
12. 报告：改动清单 + 测试输出 + 截图 + §7 逐项打勾 + gizmo 命中/角柱/放门测试断言数字。

## 7. 验收清单（全部勾选才算完成）

- [ ] 三个工具按钮可见且可切换（D1）
- [ ] 移动 gizmo=三向箭头、旋转 gizmo=旋转环、缩放 gizmo=三档跳变（D1/D2）
- [ ] 家具资产 gizmo 可完整移动/旋转；墙/结构件禁用旋转/缩放 gizmo（D1）
- [ ] 角柱锚点高亮，画墙起点只能吸附角柱（D3）
- [ ] 从角柱可拉出跨格连续墙带，`run_id` 归并（D3）
- [ ] 选中实体墙放门 → 中间墙体剔除显示门扉（D4）
- [ ] 门可单独选中/删除/移动；删门恢复实体墙（D4）
- [ ] 墙段两端端点可拖（延长/缩短/重定向出 L 转角）（D5）
- [ ] 全部操作进撤销栈，Ctrl+Z/Y 正确（保留 v3）
- [ ] headless 测试通过（§5）
- [ ] 正式回归（smoke_test / pcg_diorama_stitch_smoke）未破坏
- [ ] 缩放仍是三档（0.6/1.0/1.5），未做成连续（D2）
- [ ] 未改正式游戏流程脚本（channel_3d 等）；v1–v3 遗留文件原样

## 8. 禁止事项

- ❌ 不允许把缩放做成连续自由缩放（必须三档语义，D2）
- ❌ 不允许墙脱离外轮廓或斜放（仍限外轮廓 90°）
- ❌ 不允许画墙起点吸附到任意边界点（必须限角柱锚点，D3）
- ❌ 不允许"放门 = 在墙上再叠一个门模型"（必须替换/剔除中间墙段，D4）
- ❌ 不允许门不可独立编辑（必须可选中/删除/移动/恢复墙，D4）
- ❌ 不允许引入第三方资产/插件；不改正式游戏流程（channel_3d 等）
- ❌ 不允许 gizmo/锚点/端点手柄参与资产 AABB、模板序列化或投阴影
