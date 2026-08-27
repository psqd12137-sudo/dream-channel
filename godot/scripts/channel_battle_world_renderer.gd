class_name ChannelBattleWorldRenderer
extends RefCounted

## Runtime renderer for the tactical battle board.
## CombatRules remains authoritative; this module only materializes its state.

const RoomRules = preload("res://scripts/room_rules.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")
const CardboardShellBuilder = preload("res://scripts/cardboard_shell_builder.gd")
const APP_FONT: Font = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")
const INTENT_ATTACK_ICON: Texture2D = preload("res://assets/ui/battle_intent_attack.png")
const INTENT_RANGED_ICON: Texture2D = preload("res://assets/ui/battle_intent_ranged.png")
const INTENT_MOVE_ICON: Texture2D = preload("res://assets/ui/battle_intent_move.png")
const SALT_RING_HIT_SHEET: Texture2D = preload("res://assets/effects/salt_ring_hit_sheet.png")
const SALT_RING_TEXTURE: Texture2D = preload("res://assets/effects/salt_ring_texture.png")
const SALT_RING_TEXTURE_CHARGES_2: Texture2D = preload("res://assets/effects/salt_ring_texture_charges_2.png")
const SALT_RING_TEXTURE_CHARGES_1: Texture2D = preload("res://assets/effects/salt_ring_texture_charges_1.png")
const SALT_RING_SMOKE_SHADER: Shader = preload("res://shaders/salt_ring_smoke.gdshader")

const BATTLE_HEIGHT_ASSET_ROOT := "res://assets/quaternius/ultimate_house_interior/"
const BATTLE_FLOOR_LIGHT := "res://assets/third_party/kaykit_dungeon/models/floor_wood_large.gltf.glb"
const BATTLE_FLOOR_DARK := "res://assets/third_party/kaykit_dungeon/models/floor_wood_large_dark.gltf.glb"
const BATTLE_HEIGHT_ASSETS := {
	1: [
		"res://assets/third_party/kaykit_furniture_bits/gltf/table_low.gltf",
		"res://assets/third_party/kaykit_furniture_bits/gltf/table_medium.gltf",
		"res://assets/quaternius/ultimate_house_interior/Couch_Medium1.fbx",
	],
	2: [
		"res://assets/third_party/kaykit_dungeon/models/stairs_wood.gltf.glb",
		"res://assets/third_party/kenney_mini_dungeon/models/wood-structure.glb",
		"res://assets/third_party/kenney_mini_dungeon/models/stairs.glb",
	],
}
const BATTLE_BLOCKER_ASSETS := [
	"res://assets/third_party/kenney_mini_dungeon/models/column.glb",
	"res://assets/third_party/kenney_mini_dungeon/models/chest.glb",
	"res://assets/third_party/kenney_mini_dungeon/models/barrel.glb",
	"res://assets/quaternius/ultimate_house_interior/Bookshelf.fbx",
]

const BATTLE_CELL := 2.35
const BATTLE_SHELL_WALL_HEIGHT := 1.65
const BATTLE_SHELL_JUNCTION_WIDTH := 0.22
const COL_TEAL := Color("23aa9b")
const COL_GOLD := Color("f2a51e")
const COL_MAGENTA := Color("d63b72")
const COL_GREEN := Color("66b66d")
const COL_RED := Color("d9574f")
const COL_ENEMY_THREAT := Color("ef4444")
const COL_ENEMY_MOVE := Color("6d4cff")
const COL_WEB := Color("9b6dde")
const COL_PLAYER_MOVE := Color("fffaf2")
const COL_PLAYER_POSITION := Color("f4c542")
const COL_HOVER_VALID := Color("f5e7a1")
const COL_HOVER_INVALID := Color("ff6b6b")
const COL_RANGED_ENEMY := Color("d9574f")
const COL_RANGED_INTENT := Color("4dbbff")
const COL_BACKSTAB_ENEMY := Color("101216")
const COL_BLUE := Color("4c92bd")
const COL_GRID_DARK := Color("26343b")
const COL_FLOOR_H0 := Color("70777b")
const COL_WALL_GREEN := Color("3d6e53")
const INVALID_CELL := Vector2i(-999, -999)

enum EnemyRangeDisplayMode {
	FOCUSED,
	ALL,
	HIDDEN,
}

var host = null

var battle_root:
	get: return host.battle_root
var hud:
	get: return host.hud
var presentation:
	get: return host.presentation
var room_rules:
	get: return host.room_rules
var combat:
	get: return host.combat
var current_room_pos:
	get: return host.current_room_pos
var selected_card:
	get: return host.selected_card
var battle_camera_yaw:
	get: return host.battle_camera_yaw
var battle_player_facing_yaw:
	get: return host.battle_player_facing_yaw
var battle_enemy_facing_yaw:
	get: return host.battle_enemy_facing_yaw
var battle_room_context:
	get: return host.battle_room_context
var enemy_nodes:
	get: return host.enemy_nodes
	set(value): host.enemy_nodes = value
var battle_board_root:
	get: return host.battle_board_root
	set(value): host.battle_board_root = value
var battle_actor_root:
	get: return host.battle_actor_root
	set(value): host.battle_actor_root = value
var battle_entry_side: int:
	get: return host.battle_entry_side
var battle_entry_cell: Vector2i:
	get: return host.battle_entry_cell

var battle_hover_root: Node3D = null
var battle_target_root: Node3D = null
var battle_intent_line_root: Node3D = null
var battle_hover_markers: Array[MeshInstance3D] = []
var battle_hover_valid_markers: Array[MeshInstance3D] = []
var battle_overlay_materials: Dictionary = {}
var battle_intent_overlay_nodes: Dictionary = {}
var battle_feedback_queue: Array[Dictionary] = []
var battle_feedback_playing := false
var battle_feedback_generation := 0
var battle_intent_snapshot: Dictionary = {}
var battle_debug_hidden := false
var enemy_range_display_mode := EnemyRangeDisplayMode.FOCUSED
var enemy_arrow_display_mode := EnemyRangeDisplayMode.FOCUSED
var player_range_display_enabled := true
var player_step_display_enabled := false
var battle_triggered_traps: Dictionary = {}
var salt_ring_hit_frames: SpriteFrames = null
var full_board_build_count := 0
var incremental_refresh_count := 0
var battle_backstage_cells:
	get: return host.battle_backstage_cells
var battle_height_prop_assignments:
	get: return host.battle_height_prop_assignments
var battle_blocker_prop_assignments:
	get: return host.battle_blocker_prop_assignments
var battle_height_visual_indices:
	get: return host.battle_height_visual_indices
var previous_room_pos:
	get: return host.previous_room_pos
var battle_shell_edge_records:
	get: return host.battle_shell_edge_records
	set(value): host.battle_shell_edge_records = value
var battle_shell_culled_count:
	get: return host.battle_shell_culled_count
	set(value): host.battle_shell_culled_count = value
var battle_shell_visible_count:
	get: return host.battle_shell_visible_count
	set(value): host.battle_shell_visible_count = value
var hovered_battle_cell:
	get: return host.hovered_battle_cell
var battle_turn_actor_id:
	get: return host.battle_turn_actor_id
var combat_is_boss:
	get: return host.combat_is_boss
var boss_anchor_cells:
	get: return host.boss_anchor_cells
var boss_anchor_hp:
	get: return host.boss_anchor_hp
var boss_phase_name:
	get: return host.boss_phase_name
var active_animation_kind:
	get: return host.active_animation_kind
var battle_feedback_root:
	get: return host.battle_feedback_root

func _init(next_host) -> void:
	host = next_host


func _clear_children(parent: Node) -> void:
	host._clear_children(parent)


func clear_battle_feedback_overlay() -> void:
	battle_intent_overlay_nodes.clear()
	battle_feedback_generation += 1
	battle_feedback_queue.clear()
	battle_feedback_playing = false
	if battle_feedback_root == null:
		return
	for child: Node in battle_feedback_root.get_children():
		child.queue_free()


func _battle_world(pos: Vector2i) -> Vector3:
	return host._battle_world(pos)


func _battle_feedback_screen_position(world_position: Vector3) -> Vector2:
	return host._battle_feedback_screen_position(world_position)


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_box(parent, node_name, local_position, box_size, material)


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	return host._add_cylinder(parent, node_name, local_position, radius, height, material)


func _add_label(parent: Node3D, node_name: String, text_value: String, local_position: Vector3, color: Color, font_size: int) -> Label3D:
	return host._add_label(parent, node_name, text_value, local_position, color, font_size)


func _material(color: Color, transparent: bool = false, emission_strength: float = 0.0) -> StandardMaterial3D:
	return host._material(color, transparent, emission_strength)


func _add_decor_sprite(node_name: String, texture_path: String, local_position: Vector3, pixel_size: float, billboard: bool = true, rotation_y: float = 0.0) -> void:
	host._add_decor_sprite(node_name, texture_path, local_position, pixel_size, billboard, rotation_y)


func _add_trap_item_sprite(parent: Node3D, card_id: String, y: float) -> void:
	host._add_trap_item_sprite(parent, card_id, y)


func _ensure_battle_layers() -> void:
	if battle_board_root == null or not is_instance_valid(battle_board_root):
		battle_board_root = battle_root.get_node_or_null("BattleBoard") as Node3D
	if battle_board_root == null:
		battle_board_root = Node3D.new()
		battle_board_root.name = "BattleBoard"
		battle_root.add_child(battle_board_root)
	if battle_actor_root == null or not is_instance_valid(battle_actor_root):
		battle_actor_root = battle_root.get_node_or_null("BattleActors") as Node3D
	if battle_actor_root == null:
		battle_actor_root = Node3D.new()
		battle_actor_root.name = "BattleActors"
		battle_root.add_child(battle_actor_root)
	if battle_hover_root == null or not is_instance_valid(battle_hover_root):
		battle_hover_root = battle_root.get_node_or_null("BattleHoverOverlay") as Node3D
	if battle_hover_root == null:
		battle_hover_root = Node3D.new()
		battle_hover_root.name = "BattleHoverOverlay"
		battle_root.add_child(battle_hover_root)
	if battle_target_root == null or not is_instance_valid(battle_target_root):
		battle_target_root = battle_root.get_node_or_null("BattleTargetOverlay") as Node3D
	if battle_target_root == null:
		battle_target_root = Node3D.new()
		battle_target_root.name = "BattleTargetOverlay"
		battle_root.add_child(battle_target_root)
	if battle_intent_line_root == null or not is_instance_valid(battle_intent_line_root):
		battle_intent_line_root = battle_root.get_node_or_null("BattleIntentLines") as Node3D
	if battle_intent_line_root == null:
		battle_intent_line_root = Node3D.new()
		battle_intent_line_root.name = "BattleIntentLines"
		battle_root.add_child(battle_intent_line_root)


func build_battle_world() -> void:
	full_board_build_count += 1
	battle_triggered_traps.clear()
	clear_battle_feedback_overlay()
	_ensure_battle_layers()
	_clear_children(battle_intent_line_root)
	_clear_children(battle_board_root)
	_clear_children(battle_actor_root)
	enemy_nodes.clear()
	battle_intent_snapshot = combat.preview_all_intents() if combat != null else {}
	_build_battle_board()
	_sync_battle_actors()
	_update_battle_overlays()


func reset_battle_display_preferences() -> void:
	# 显示偏好属于一场战斗的交互状态；完整重绘不能覆盖玩家刚刚选择的模式。
	enemy_range_display_mode = EnemyRangeDisplayMode.FOCUSED
	enemy_arrow_display_mode = EnemyRangeDisplayMode.FOCUSED
	player_range_display_enabled = true
	player_step_display_enabled = host.test_combat_active


func refresh_battle_board() -> void:
	# 敌方事件已经先结算逻辑状态；动画期间只更新静态棋盘上的动态标记，
	# 演员节点必须保留在原位，交给事件动画逐格移动。
	refresh_battle_state(false, false)


func refresh_battle_state(sync_actors := true, sync_actor_positions := false) -> void:
	if combat == null:
		return
	incremental_refresh_count += 1
	_ensure_battle_layers()
	# 一次动态刷新只规划一轮全体敌人，格子和头顶标记共享同一份快照。
	battle_intent_snapshot = combat.preview_all_intents()
	_refresh_battle_dynamic_visuals()
	if sync_actors:
		_reconcile_battle_actors(sync_actor_positions)
	_update_battle_overlays()


func refresh_battle_selection_visuals() -> void:
	# 选中敌人只改变演员上的描边，不需要重建棋盘或重新同步位置。
	if combat == null:
		return
	for raw_enemy_id in combat.living_enemy_ids():
		var enemy_id: String = str(raw_enemy_id)
		var state = combat.enemy_by_id(enemy_id)
		var enemy_node: Node3D = _enemy_node_for_id(enemy_id)
		if state != null and enemy_node != null:
			_refresh_enemy_selection_outline(enemy_node, state)


func update_battle_overlays() -> void:
	_ensure_battle_layers()
	_update_battle_overlays()


func update_battle_debug_visibility() -> void:
	if battle_board_root == null:
		return
	var should_hide: bool = not _battle_debug_visible()
	if should_hide == battle_debug_hidden:
		return
	battle_debug_hidden = should_hide
	_clear_battle_target_markers()
	_refresh_battle_dynamic_visuals()
	_update_battle_hover_marker()
	if not should_hide:
		_update_battle_target_markers()


func _battle_debug_visible() -> bool:
	# 敌方回合的逻辑状态会先结算，动画状态再逐步表现；因此不能只依赖
	# animation_busy。过渡帧仍标记为 enemy_turn 时，所有预览层都必须隐藏。
	return not host.animation_busy and str(active_animation_kind) != "enemy_turn"


func _battle_enemy_intel_visible() -> bool:
	return host != null and host.has_method("enemy_intel_visible") and bool(host.enemy_intel_visible())


func set_battle_triggered_traps(events: Array[Dictionary]) -> void:
	battle_triggered_traps.clear()
	for event: Dictionary in events:
		if str(event.get("kind", "")) not in ["enemy_damaged", "enemy_trap_triggered"] or not str(event.get("source", "")).begins_with("trap:"):
			continue
		var target: Vector2i = event.get("target", INVALID_CELL)
		var trap: Variant = event.get("trap", {})
		if target != INVALID_CELL and trap is Dictionary:
			battle_triggered_traps[target] = (trap as Dictionary).duplicate(true)


func clear_battle_triggered_traps() -> void:
	battle_triggered_traps.clear()


func consume_battle_triggered_trap(target: Vector2i) -> void:
	if not battle_triggered_traps.has(target):
		return
	battle_triggered_traps.erase(target)
	var cell_node := battle_board_root.get_node_or_null("Cell_%d_%d" % [target.x, target.y]) as Node3D
	if cell_node == null:
		return
	for child: Node in cell_node.get_children():
		if child.name.begins_with("Trap") or child.name.begins_with("ItemArt_"):
			child.free()


func cycle_enemy_range_display() -> String:
	enemy_range_display_mode = (enemy_range_display_mode + 1) % EnemyRangeDisplayMode.size()
	_refresh_battle_dynamic_visuals()
	return enemy_range_display_mode_label()


func cycle_enemy_range_scope() -> String:
	enemy_range_display_mode = (enemy_range_display_mode + 1) % EnemyRangeDisplayMode.size()
	_refresh_battle_dynamic_visuals()
	return enemy_range_scope_label()


func toggle_enemy_range_scope() -> String:
	# 保留旧接口，避免测试台之外的调用方失效；显示面板使用三态循环。
	return cycle_enemy_range_scope()


func enemy_range_display_mode_label() -> String:
	match enemy_range_display_mode:
		EnemyRangeDisplayMode.ALL:
			return "全体敌人"
		EnemyRangeDisplayMode.HIDDEN:
			return "不显示"
	return "单个敌人"


func enemy_range_scope_label() -> String:
	match enemy_range_display_mode:
		EnemyRangeDisplayMode.ALL:
			return "全体"
		EnemyRangeDisplayMode.HIDDEN:
			return "关闭"
	return "仅选中"


func cycle_enemy_arrow_scope() -> String:
	enemy_arrow_display_mode = (enemy_arrow_display_mode + 1) % EnemyRangeDisplayMode.size()
	_refresh_battle_intent_arrows()
	return enemy_arrow_scope_label()


func toggle_enemy_arrow_scope() -> String:
	return cycle_enemy_arrow_scope()


func enemy_arrow_scope_label() -> String:
	match enemy_arrow_display_mode:
		EnemyRangeDisplayMode.ALL:
			return "全体"
		EnemyRangeDisplayMode.HIDDEN:
			return "关闭"
	return "仅选中"


func toggle_player_range_display() -> bool:
	player_range_display_enabled = not player_range_display_enabled
	_refresh_battle_dynamic_visuals()
	return player_range_display_enabled


func toggle_player_step_display() -> bool:
	player_step_display_enabled = not player_step_display_enabled
	_refresh_battle_dynamic_visuals()
	return player_step_display_enabled


func player_range_display_label() -> String:
	return "显示" if player_range_display_enabled else "隐藏"


func player_step_display_label() -> String:
	return "显示" if player_step_display_enabled else "隐藏"


func update_battle_hover() -> void:
	_ensure_battle_layers()
	# 悬停反馈改由格子覆层绘制，鼠标移动时刷新当前格子的有效/无效状态。
	_refresh_battle_dynamic_visuals()
	_update_battle_hover_marker()


func _update_battle_overlays() -> void:
	_update_battle_target_markers()
	_update_battle_hover_marker()


func _update_battle_target_markers() -> void:
	_clear_battle_target_markers()
	if combat == null or combat.outcome != "" or selected_card < 0:
		return
	for y in range(combat.rows):
		for x in range(combat.cols):
			var pos := Vector2i(x, y)
			if not _is_valid_battle_target(pos):
				continue
			var cell_node := battle_board_root.get_node_or_null("Cell_%d_%d" % [x, y]) as Node3D
			if cell_node != null:
				_add_corner_marks(cell_node, "CardValid", COL_GOLD, _battle_cell_top_y(pos))


func _clear_battle_target_markers() -> void:
	if battle_board_root == null:
		return
	for child: Node in battle_board_root.get_children():
		if not child.name.begins_with("Cell_"):
			continue
		for marker: Node in child.get_children():
			if marker.name.begins_with("CardValid_"):
				marker.free()


func _update_battle_hover_marker() -> void:
	if battle_hover_root == null:
		return
	# 保留旧数组兼容已有场景，但不再把四个角点挂到棋盘上。
	_set_corner_marker_group(battle_hover_markers, false, Color.WHITE, 0.0)
	_set_corner_marker_group(battle_hover_valid_markers, false, COL_GREEN, 0.0)


func _ensure_battle_hover_markers() -> void:
	if not battle_hover_markers.is_empty() and is_instance_valid(battle_hover_markers[0]):
		return
	battle_hover_markers.clear()
	battle_hover_valid_markers.clear()
	for index in range(4):
		var hover_marker := _add_box(battle_hover_root, "Hover_%d" % index, Vector3.ZERO, Vector3(0.28, 0.055, 0.28), _overlay_material(Color.WHITE))
		battle_hover_markers.append(hover_marker)
		var valid_marker := _add_box(battle_hover_root, "Valid_%d" % index, Vector3.ZERO, Vector3(0.28, 0.055, 0.28), _overlay_material(COL_GREEN))
		battle_hover_valid_markers.append(valid_marker)


func _set_corner_marker_group(markers: Array[MeshInstance3D], visible: bool, color: Color, y: float) -> void:
	var edge := BATTLE_CELL * 0.36
	for index in range(markers.size()):
		var marker := markers[index]
		if marker == null or not is_instance_valid(marker):
			continue
		var sx := -1.0 if index % 2 == 0 else 1.0
		var sz := -1.0 if index < 2 else 1.0
		marker.position = Vector3(sx * edge, y, sz * edge)
		marker.material_override = _overlay_material(color)
		marker.visible = visible


func _overlay_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if not battle_overlay_materials.has(key):
		battle_overlay_materials[key] = _material(color, false, 0.08)
	return battle_overlay_materials[key] as StandardMaterial3D


func _battle_cell_in_bounds(pos: Vector2i) -> bool:
	return combat != null and pos.x >= 0 and pos.y >= 0 and pos.x < combat.cols and pos.y < combat.rows


func _battle_cell_top_y(pos: Vector2i) -> float:
	var height := int(combat.heights.get(pos, 0)) if combat != null else 0
	return 0.28 + float(height) * 0.64 + 0.13


func _build_battle_board() -> void:
	if combat == null:
		return
	var room_floor_a: Color = battle_room_context.get("floor_a", COL_FLOOR_H0)
	var room_floor_b: Color = battle_room_context.get("floor_b", room_floor_a.darkened(0.035))
	var room_rim: Color = battle_room_context.get("rim", Color("343a3e"))
	var room_blocker: Color = battle_room_context.get("blocker", COL_WALL_GREEN)
	_add_box(
		battle_board_root,
		"ArenaBase",
		Vector3(0, -0.13, 0),
		Vector3(float(combat.cols) * BATTLE_CELL + 0.36, 0.22, float(combat.rows) * BATTLE_CELL + 0.36),
		_material(room_rim.darkened(0.52))
	)
	for y in range(combat.rows):
		for x in range(combat.cols):
			var pos := Vector2i(x, y)
			var world := _battle_world(pos)
			var cell_node := Node3D.new()
			cell_node.name = "Cell_%d_%d" % [x, y]
			cell_node.position = world
			battle_board_root.add_child(cell_node)
			var height := int(combat.heights.get(pos, 0))
			var footprint_active := _battle_cell_in_room_footprint(pos)
			var backstage: bool = battle_backstage_cells.has(pos)
			cell_node.set_meta("room_footprint_active", footprint_active)
			var platform_height := 0.28 + float(height) * 0.64
			var rim_color := room_rim if height == 0 else room_rim.darkened(0.12) if height == 1 else room_rim.darkened(0.24)
			var surface_color := room_floor_a if (x + y) % 2 == 0 else room_floor_b
			if height == 1:
				surface_color = surface_color.darkened(0.12)
			elif height >= 2:
				surface_color = surface_color.darkened(0.24)
			if combat.walls.has(pos) and not backstage:
				surface_color = room_blocker.darkened(0.12)
			elif not footprint_active:
				rim_color = room_rim.darkened(0.42)
				surface_color = room_rim.darkened(0.56)
			if height == 0:
				_add_box(cell_node, "Frame", Vector3(0, platform_height * 0.5, 0), Vector3(BATTLE_CELL - 0.08, platform_height, BATTLE_CELL - 0.08), _material(rim_color, false, 0.04 if rim_color != COL_GRID_DARK else 0.0))
			else:
				_add_box(cell_node, "TerrainFoot", Vector3(0, 0.14, 0), Vector3(BATTLE_CELL - 0.08, 0.28, BATTLE_CELL - 0.08), _material(rim_color))
				_add_battle_height_asset(cell_node, pos, height, platform_height + 0.13)
			cell_node.set_meta("battle_base_rim", rim_color)
			_add_battle_floor_model(cell_node, pos, footprint_active)
			# Surface remains only as a picking/standing plane. The visible finish is
			# the same KayKit timber module used by the formal big-map composer.
			var surface_alpha := 0.025 if height == 0 else 0.018
			var surface_material := _material(Color(surface_color, surface_alpha), true, 0.018)
			_add_box(cell_node, "Surface", Vector3(0, platform_height + 0.055, 0), Vector3(BATTLE_CELL - 0.34, 0.11, BATTLE_CELL - 0.34), surface_material)
			var top_y := platform_height + 0.13
			# 移动和出牌目标角标属于交互覆盖层，不能跟着整张棋盘反复重建。
			# 这里只生成房间本体；动态危险标记和角标由独立刷新路径维护。
			if combat.portals.has(pos):
				_add_portal_marker(cell_node, pos, top_y)
			if combat.walls.has(pos) and not backstage:
				var blocker_volume := _add_box(cell_node, "Blocker", Vector3(0, platform_height + 0.70, 0), Vector3(BATTLE_CELL - 0.48, 1.20, BATTLE_CELL - 0.48), _material(Color(room_blocker, 0.03), true, 0.0))
				blocker_volume.visible = false
				_add_battle_blocker_asset(cell_node, pos, platform_height)
			elif combat.traps.has(pos):
				var trap: Dictionary = combat.traps[pos]
				_add_trap_visual(cell_node, trap, top_y)
			if combat_is_boss and pos in boss_anchor_cells:
				_add_boss_anchor_visual(cell_node, pos, top_y)
	_add_battle_room_shell()
	_add_battle_stage_decor()
	_refresh_battle_dynamic_visuals()


func _add_boss_anchor_visual(cell_node: Node3D, cell: Vector2i, top_y: float) -> void:
	var remaining := int(boss_anchor_hp.get(cell, 0))
	var active := remaining > 0
	var color := Color("f2a51e") if active else Color("5b6267")
	var core := _add_cylinder(cell_node, "BossAnchorCore", Vector3(0, top_y + 0.24, 0), 0.24, 0.48, _material(color, false, 0.22 if active else 0.0))
	core.rotation.x = 0.0
	_add_cylinder(cell_node, "BossAnchorRing", Vector3(0, top_y + 0.055, 0), 0.54, 0.06, _material(Color(color, 0.80), true, 0.12 if active else 0.0))
	_add_label(cell_node, "BossAnchorLabel", "锚 %d" % remaining if active else "锚·熄灭", Vector3(0, top_y + 0.82, 0), Color("ffe8a3") if active else Color("9ba4a9"), 13)


func _battle_intent_cells() -> Dictionary:
	var intent_cells: Dictionary = {}
	if combat == null:
		return intent_cells
	if not _battle_debug_visible():
		return intent_cells
	# 测试场景的范围面板是独立的观察工具，不能因为当前选中了卡牌
	# 就把玩家可达格和步数一起隐藏；正式战斗仍保持卡牌目标优先。
	var show_player_reach: bool = player_range_display_enabled and (selected_card < 0 or host.test_combat_active)
	if show_player_reach:
		for raw_cell in combat.player_reachable_cells():
			var player_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(player_entry["player_move"] as Array).append({"intent": {"enemy_id": "player"}})
			intent_cells[raw_cell] = player_entry
	if selected_card < 0 and (combat.energy <= 0 or host.player_facing_selection_requested):
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var facing_cell: Vector2i = combat.player_pos + direction
			if not _battle_cell_in_bounds(facing_cell):
				continue
			var facing_entry: Dictionary = intent_cells.get(facing_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": [], "player_facing": []})
			var facing_markers: Array = facing_entry.get("player_facing", [])
			facing_markers.append({"direction": direction})
			facing_entry["player_facing"] = facing_markers
			intent_cells[facing_cell] = facing_entry
	var focused_enemy_id := _focused_battle_enemy_id()
	for enemy_id in combat.living_enemy_ids():
		if not _enemy_range_display_allows(enemy_id, focused_enemy_id):
			continue
		var enemy_intent: Dictionary = battle_intent_snapshot.get(enemy_id, {})
		if enemy_intent.is_empty():
			continue
		var enemy_state = combat.enemy_by_id(enemy_id)
		if enemy_state == null or (not enemy_state.revealed and not _battle_enemy_intel_visible()):
			continue
		for raw_cell in enemy_intent.get("move_cells", []):
			var move_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(move_entry["enemy_move"] as Array).append({"enemy_id": enemy_id, "intent": enemy_intent})
			intent_cells[raw_cell] = move_entry
		for raw_cell in enemy_intent.get("threat_cells", []):
			var threat_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(threat_entry["threat"] as Array).append({"enemy_id": enemy_id, "intent": enemy_intent})
			intent_cells[raw_cell] = threat_entry
		for raw_cell in enemy_intent.get("impact_cells", enemy_intent.get("hurt", [])):
			var impact_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(impact_entry["impact"] as Array).append({"enemy_id": enemy_id, "intent": enemy_intent})
			intent_cells[raw_cell] = impact_entry
		for raw_cell in enemy_intent.get("web_cells", []):
			var web_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			var web_markers: Array = web_entry.get("web", [])
			web_markers.append({"enemy_id": enemy_id, "intent": enemy_intent})
			web_entry["web"] = web_markers
			intent_cells[raw_cell] = web_entry
		for raw_cell in enemy_intent.get("path", []):
			var path_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(path_entry["path"] as Array).append({"enemy_id": enemy_id, "intent": enemy_intent})
			intent_cells[raw_cell] = path_entry
		for raw_cell in enemy_intent.get("line_cells", []):
			var line_entry: Dictionary = intent_cells.get(raw_cell, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			(line_entry["line"] as Array).append({"enemy_id": enemy_id, "intent": enemy_intent})
			intent_cells[raw_cell] = line_entry
	return intent_cells


func _enemy_range_display_allows(enemy_id: String, focused_enemy_id: String) -> bool:
	if enemy_range_display_mode == EnemyRangeDisplayMode.HIDDEN:
		return false
	if enemy_range_display_mode == EnemyRangeDisplayMode.ALL:
		return true
	return enemy_id == focused_enemy_id


func _enemy_arrow_display_allows(enemy_id: String, focused_enemy_id: String) -> bool:
	if enemy_arrow_display_mode == EnemyRangeDisplayMode.HIDDEN:
		return false
	if enemy_arrow_display_mode == EnemyRangeDisplayMode.ALL:
		return true
	return enemy_id == focused_enemy_id


func _clear_battle_cell_dynamic(cell_node: Node3D) -> void:
	for child: Node in cell_node.get_children():
		if child.name.begins_with("Intent") or child.name.begins_with("Trap") or child.name.begins_with("ItemArt_") or child.name.begins_with("PlayerReachable") or child.name.begins_with("PlayerFacing") or child.name.begins_with("PlayerPosition") or child.name.begins_with("EnemyReachable") or child.name.begins_with("Hover"):
			child.free()


func _refresh_battle_dynamic_visuals() -> void:
	if combat == null or battle_board_root == null:
		return
	var show_battle_debug: bool = _battle_debug_visible()
	if battle_intent_snapshot.is_empty():
		battle_intent_snapshot = combat.preview_all_intents()
	_refresh_battle_intent_arrows()
	_refresh_boss_anchor_visuals()
	var intent_cells := _battle_intent_cells()
	for y in range(combat.rows):
		for x in range(combat.cols):
			var pos := Vector2i(x, y)
			var cell_node := battle_board_root.get_node_or_null("Cell_%d_%d" % [x, y]) as Node3D
			if cell_node == null:
				continue
			_clear_battle_cell_dynamic(cell_node)
			var base_rim: Color = cell_node.get_meta("battle_base_rim", COL_GRID_DARK)
			var cell_intent: Dictionary = intent_cells.get(pos, {"impact": [], "threat": [], "player_move": [], "enemy_move": [], "path": [], "line": []})
			var impacts: Array = cell_intent.get("impact", [])
			var threats: Array = cell_intent.get("threat", [])
			var player_moves: Array = cell_intent.get("player_move", [])
			var player_facing: Array = cell_intent.get("player_facing", [])
			var enemy_moves: Array = cell_intent.get("enemy_move", [])
			var webs: Array = cell_intent.get("web", [])
			var paths: Array = cell_intent.get("path", [])
			var lines: Array = cell_intent.get("line", [])
			var rim_color := base_rim
			if show_battle_debug and pos == combat.player_pos:
				rim_color = COL_PLAYER_POSITION
			elif show_battle_debug and not impacts.is_empty():
				rim_color = COL_RED
			elif show_battle_debug and not threats.is_empty():
				rim_color = COL_ENEMY_THREAT
			elif show_battle_debug and not player_facing.is_empty():
				rim_color = COL_GOLD
			elif show_battle_debug and not webs.is_empty():
				rim_color = COL_WEB
			elif show_battle_debug and not player_moves.is_empty():
				rim_color = COL_PLAYER_MOVE
			elif show_battle_debug and not enemy_moves.is_empty():
				rim_color = COL_ENEMY_MOVE
			var rim_node := cell_node.get_node_or_null("Frame") as MeshInstance3D
			if rim_node == null:
				rim_node = cell_node.get_node_or_null("TerrainFoot") as MeshInstance3D
			if rim_node != null:
				rim_node.material_override = _material(rim_color, false, 0.04 if rim_color != COL_GRID_DARK else 0.0)
			var top_y := _battle_cell_top_y(pos)
			if show_battle_debug:
				if pos == combat.player_pos:
					_add_battle_cell_fill(cell_node, "PlayerPositionFill", top_y, COL_PLAYER_POSITION, 0.42)
				if not impacts.is_empty():
					_add_battle_cell_fill(cell_node, "IntentAttackOverlayFill", top_y, COL_RED, 0.88)
				elif not threats.is_empty():
					_add_battle_cell_fill(cell_node, "IntentThreatFill", top_y, COL_ENEMY_THREAT, 0.50)
				elif not player_facing.is_empty():
					_add_battle_cell_fill(cell_node, "PlayerFacingFill", top_y, COL_GOLD, 0.28)
					var facing_direction := Vector2i((player_facing[0] as Dictionary).get("direction", Vector2i.ZERO))
					_add_label(cell_node, "PlayerFacingGlyph", _battle_facing_glyph(facing_direction), Vector3(0, top_y + 0.30, 0), Color("fffaf2", 0.98), 18)
				elif not webs.is_empty():
					_add_battle_cell_fill(cell_node, "IntentWebFill", top_y, COL_WEB, 0.42)
				elif not player_moves.is_empty():
					_add_battle_cell_fill(cell_node, "PlayerReachableFill", top_y, COL_PLAYER_MOVE, 0.22)
				elif not enemy_moves.is_empty():
					_add_battle_cell_fill(cell_node, "IntentMoveOverlayFill", top_y, COL_ENEMY_MOVE, 0.28)
				if player_step_display_enabled and not player_moves.is_empty():
					var player_path: Array[Vector2i] = combat.player_path_to(pos)
					var player_steps := maxi(0, player_path.size() - 1)
					if player_steps > 0:
						var step_label := _add_label(cell_node, "PlayerReachableStep", str(player_steps), Vector3(0, top_y + 0.27, 0), COL_GRID_DARK, 20)
						# 步数是范围预览的核心信息：置于格子中心、关闭深度测试，
						# 并用浅色描边保证在红/蓝/木地板上都能读到。
						step_label.pixel_size = 0.016
						step_label.modulate = Color(COL_GRID_DARK, 0.98)
						step_label.outline_modulate = Color("fffaf2", 0.96)
						step_label.outline_size = 10
						step_label.render_priority = 24
				if not paths.is_empty() and impacts.is_empty():
					if threats.is_empty() and enemy_moves.is_empty():
						_add_battle_cell_fill(cell_node, "IntentMoveOverlayFill", top_y, COL_ENEMY_MOVE, 0.42)
				elif not lines.is_empty():
					_add_box(
						cell_node,
						"IntentLineOverlay",
						Vector3(0, top_y + 0.026, 0),
						Vector3(0.16, 0.04, 0.16),
						_material(Color(COL_ENEMY_THREAT, 0.72), true, 0.12)
					)
				var glyph_entry: Dictionary = {}
				var glyph_node_prefix := ""
				if not impacts.is_empty():
					glyph_entry = impacts[0]
					glyph_node_prefix = "IntentAttackGlyph"
				elif not enemy_moves.is_empty():
					glyph_entry = enemy_moves[0]
					glyph_node_prefix = "IntentMoveGlyph"
				# 网格只保留网的地面效果和持续回合数，不在每个格子重复显示“网”字。
				elif not paths.is_empty():
					glyph_entry = paths[0]
					glyph_node_prefix = "IntentMoveGlyph"
				if show_battle_debug and not glyph_entry.is_empty():
					var glyph_intent: Dictionary = glyph_entry.get("intent", {})
					var glyph_type := str(glyph_intent.get("type", "stall"))
					var glyph_attack_kind := str(glyph_intent.get("attack_kind", ""))
					var glyph_color := _battle_intent_color(glyph_type)
					_add_label(
						cell_node,
						glyph_node_prefix,
						_battle_intent_glyph(glyph_type, glyph_attack_kind),
						Vector3(0, top_y + 0.30, 0),
						Color(glyph_color, 0.96),
						18
					)
				if pos == hovered_battle_cell:
					var hover_valid := _is_valid_battle_target(pos)
					_add_battle_cell_fill(cell_node, "HoverValidFill" if hover_valid else "HoverInvalidFill", top_y, COL_HOVER_VALID if hover_valid else COL_HOVER_INVALID, 0.18)
					if not hover_valid and selected_card < 0:
						_add_label(cell_node, "HoverInvalidGlyph", "×", Vector3(0, top_y + 0.26, 0), COL_HOVER_INVALID, 28)
			var visible_trap: Dictionary = combat.traps.get(pos, {})
			if battle_triggered_traps.has(pos):
				visible_trap = battle_triggered_traps[pos]
			if not visible_trap.is_empty():
				var trap: Dictionary = visible_trap
				_add_trap_visual(cell_node, trap, top_y)


func _refresh_boss_anchor_visuals() -> void:
	if not combat_is_boss or battle_board_root == null:
		return
	for cell: Vector2i in boss_anchor_cells:
		var cell_node := battle_board_root.get_node_or_null("Cell_%d_%d" % [cell.x, cell.y]) as Node3D
		if cell_node == null:
			continue
		var remaining := int(boss_anchor_hp.get(cell, 0))
		var active := remaining > 0
		var color := Color("f2a51e") if active else Color("5b6267")
		var core := cell_node.get_node_or_null("BossAnchorCore") as MeshInstance3D
		if core != null:
			core.material_override = _material(color, false, 0.22 if active else 0.0)
		var ring := cell_node.get_node_or_null("BossAnchorRing") as MeshInstance3D
		if ring != null:
			ring.material_override = _material(Color(color, 0.80), true, 0.12 if active else 0.0)
		var label := cell_node.get_node_or_null("BossAnchorLabel") as Label3D
		if label != null:
			label.text = "锚 %d" % remaining if active else "锚·熄灭"
			label.modulate = Color("ffe8a3") if active else Color("9ba4a9")


func _refresh_battle_intent_arrows() -> void:
	if battle_intent_line_root == null or not is_instance_valid(battle_intent_line_root):
		return
	_clear_children(battle_intent_line_root)
	if not _battle_debug_visible():
		return
	var focused_enemy_id := _focused_battle_enemy_id()
	for enemy_id in combat.living_enemy_ids():
		if not _enemy_arrow_display_allows(enemy_id, focused_enemy_id):
			continue
		var state = combat.enemy_by_id(enemy_id)
		var intent: Dictionary = battle_intent_snapshot.get(enemy_id, {})
		if state == null or (not state.revealed and not _battle_enemy_intel_visible()) or intent.is_empty():
			continue
		var impact_cells: Array = intent.get("impact_cells", intent.get("hurt", []))
		if not impact_cells.is_empty():
			var attack_paths := _battle_intent_attack_paths(state.pos, intent)
			for index in range(attack_paths.size()):
				_add_battle_intent_path_arrow(attack_paths[index], COL_GREEN, "%s_%d" % [enemy_id, index])
			continue
		var web_cells: Array = intent.get("web_cells", [])
		if not web_cells.is_empty():
			var blocked: Dictionary = combat.occupied_enemy_cells(enemy_id)
			for index in range(web_cells.size()):
				var target := Vector2i(web_cells[index])
				var web_path: Array[Vector2i] = combat._find_path(state.pos, target, blocked, false)
				_add_battle_intent_path_arrow(web_path, COL_WEB, "%s_web_%d" % [enemy_id, index])
			continue
		var path_cells: Array = intent.get("path", [])
		if path_cells.is_empty():
			continue
		var movement_path: Array = [state.pos]
		movement_path.append_array(path_cells)
		_add_battle_intent_path_arrow(movement_path, COL_GREEN, "%s_move" % enemy_id)


func _battle_intent_attack_paths(state_pos: Vector2i, intent: Dictionary) -> Array:
	# 攻击意图可能包含“先移动、再攻击”。只画攻击起点到目标的直线
	# 会把中间的寻路拐点抹掉，因此要把实际移动路径接到攻击目标上。
	var impact_cells: Array = intent.get("impact_cells", intent.get("hurt", []))
	if impact_cells.is_empty():
		return []
	var path_cells: Array = intent.get("path", [])
	var route_origin := state_pos
	if path_cells.is_empty():
		var raw_origin: Variant = intent.get("range_origin", INVALID_CELL)
		if raw_origin is Vector2i and raw_origin != INVALID_CELL:
			route_origin = raw_origin
	var movement_path: Array[Vector2i] = [route_origin]
	for raw_cell: Variant in path_cells:
		var cell := Vector2i(raw_cell)
		if movement_path.back() != cell:
			movement_path.append(cell)
	var routes: Array = []
	for raw_target: Variant in impact_cells:
		var route: Array[Vector2i] = movement_path.duplicate()
		var target := Vector2i(raw_target)
		if route.back() != target:
			route.append(target)
		routes.append(route)
	return routes


func _add_battle_intent_arrow(source: Vector2i, target: Vector2i, color: Color, suffix: String) -> void:
	_add_battle_intent_path_arrow([source, target], color, suffix)


func _add_battle_intent_path_arrow(raw_path: Array, color: Color, suffix: String) -> void:
	if raw_path.size() < 2:
		return
	var points: Array[Vector2i] = []
	for raw_cell: Variant in raw_path:
		var cell := Vector2i(raw_cell)
		if cell == INVALID_CELL:
			return
		if points.is_empty() or points.back() != cell:
			points.append(cell)
	if points.size() < 2:
		return
	var world_points: Array[Vector3] = []
	var arrow_y := -INF
	for cell: Vector2i in points:
		var world := _battle_world(cell)
		world_points.append(world)
		arrow_y = maxf(arrow_y, _battle_cell_top_y(cell) + 0.20)
	var head_width := 0.22
	var shaft_half_width := 0.055
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(world_points.size() - 1):
		var start := Vector2(world_points[index].x, world_points[index].z)
		var end := Vector2(world_points[index + 1].x, world_points[index + 1].z)
		var direction := end - start
		var length := direction.length()
		if length < 0.05:
			continue
		direction /= length
		var side := Vector2(-direction.y, direction.x)
		var is_last_segment := index == world_points.size() - 2
		var shaft_start := start + direction * (0.12 if index == 0 else 0.0)
		var shaft_end := end
		if is_last_segment:
			var head_length := minf(0.55, length * 0.38)
			var head_base := end - direction * head_length
			shaft_end = head_base + direction * 0.04
		var shaft_start_left := shaft_start + side * shaft_half_width
		var shaft_start_right := shaft_start - side * shaft_half_width
		var shaft_end_left := shaft_end + side * shaft_half_width
		var shaft_end_right := shaft_end - side * shaft_half_width
		if shaft_start.distance_to(shaft_end) >= 0.02:
			mesh.surface_add_vertex(Vector3(shaft_start_left.x, arrow_y, shaft_start_left.y))
			mesh.surface_add_vertex(Vector3(shaft_start_right.x, arrow_y, shaft_start_right.y))
			mesh.surface_add_vertex(Vector3(shaft_end_left.x, arrow_y, shaft_end_left.y))
			mesh.surface_add_vertex(Vector3(shaft_start_right.x, arrow_y, shaft_start_right.y))
			mesh.surface_add_vertex(Vector3(shaft_end_right.x, arrow_y, shaft_end_right.y))
			mesh.surface_add_vertex(Vector3(shaft_end_left.x, arrow_y, shaft_end_left.y))
		if is_last_segment:
			var head_base := end - direction * minf(0.55, length * 0.38)
			var head_left := head_base + side * head_width
			var head_right := head_base - side * head_width
			mesh.surface_add_vertex(Vector3(end.x, arrow_y, end.y))
			mesh.surface_add_vertex(Vector3(head_left.x, arrow_y, head_left.y))
			mesh.surface_add_vertex(Vector3(head_right.x, arrow_y, head_right.y))
	# A small diamond at every turn keeps adjacent segment quads visually joined.
	for index in range(1, world_points.size() - 1):
		var joint := Vector2(world_points[index].x, world_points[index].z)
		var radius := shaft_half_width * 1.35
		var joint_top := joint + Vector2(0, -radius)
		var joint_right := joint + Vector2(radius, 0)
		var joint_bottom := joint + Vector2(0, radius)
		var joint_left := joint + Vector2(-radius, 0)
		mesh.surface_add_vertex(Vector3(joint_top.x, arrow_y, joint_top.y))
		mesh.surface_add_vertex(Vector3(joint_right.x, arrow_y, joint_right.y))
		mesh.surface_add_vertex(Vector3(joint_bottom.x, arrow_y, joint_bottom.y))
		mesh.surface_add_vertex(Vector3(joint_top.x, arrow_y, joint_top.y))
		mesh.surface_add_vertex(Vector3(joint_bottom.x, arrow_y, joint_bottom.y))
		mesh.surface_add_vertex(Vector3(joint_left.x, arrow_y, joint_left.y))
	mesh.surface_end()
	var arrow := MeshInstance3D.new()
	arrow.name = "EnemyIntentArrow_%s" % suffix.replace(":", "_").replace("/", "_")
	arrow.mesh = mesh
	var material := _material(Color(color, 0.94), true, 0.18)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	arrow.material_override = material
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	battle_intent_line_root.add_child(arrow)


func _add_battle_cell_fill(parent: Node3D, node_name: String, top_y: float, color: Color, alpha: float) -> MeshInstance3D:
	return _add_box(
		parent,
		node_name,
		Vector3(0, top_y + 0.026, 0),
		Vector3(BATTLE_CELL - 0.16, 0.035, BATTLE_CELL - 0.16),
		_material(Color(color, alpha), true, 0.10)
	)


func _add_trap_visual(cell_node: Node3D, trap: Dictionary, top_y: float) -> void:
	var card_id := str(trap.get("card_id", ""))
	if card_id in ["salt", "guard"]:
		var charges := int(trap.get("charges", 3))
		if charges <= 0:
			return
		var salt_texture: Texture2D = SALT_RING_TEXTURE
		if charges == 2:
			salt_texture = SALT_RING_TEXTURE_CHARGES_2
		elif charges == 1:
			salt_texture = SALT_RING_TEXTURE_CHARGES_1
		var salt_material := ShaderMaterial.new()
		salt_material.shader = SALT_RING_SMOKE_SHADER
		salt_material.set_shader_parameter("salt_texture", salt_texture)
		salt_material.set_shader_parameter("salt_tint", Color("fff3d1"))
		salt_material.set_shader_parameter("opacity", 0.94)
		salt_material.set_shader_parameter("rotation_speed", 0.08)
		salt_material.set_shader_parameter("shimmer", 0.008)
		var salt_ring := MeshInstance3D.new()
		salt_ring.name = "Trap"
		var salt_mesh := QuadMesh.new()
		salt_mesh.size = Vector2(1.98, 1.98)
		salt_ring.mesh = salt_mesh
		salt_ring.material_override = salt_material
		salt_ring.position = Vector3(0, top_y + 0.07, 0)
		salt_ring.rotation.x = -PI * 0.5
		salt_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		salt_ring.set_meta("collision_free", true)
		cell_node.add_child(salt_ring)
		return
	if card_id == "web":
		_add_cylinder(cell_node, "Trap", Vector3(0, top_y + 0.06, 0), 0.46, 0.055, _material(Color(COL_WEB, 0.86), true, 0.035))
		var remaining_rounds := maxi(0, int(trap.get("expires_round", combat.round_number + 1)) - combat.round_number)
		if remaining_rounds > 0:
			_add_label(cell_node, "TrapDuration", str(remaining_rounds), Vector3(0, top_y + 0.62, 0), Color("fff5ff", 0.98), 16)
		return
	_add_cylinder(cell_node, "Trap", Vector3(0, top_y + 0.08, 0), 0.30, 0.13, _material(COL_GOLD, false, 0.05))
	_add_trap_item_sprite(cell_node, card_id, top_y)
	_add_label(cell_node, "TrapGlyph", str(trap.get("glyph", "✦")), Vector3(0, top_y + 0.62, 0), COL_GOLD, 21)


func _sync_battle_actors() -> void:
	if combat == null:
		return
	_add_battle_pawn(combat.player_pos, true, true)
	for enemy_id in combat.living_enemy_ids():
		var state = combat.enemy_by_id(enemy_id)
		if state != null:
			_add_battle_pawn(state.pos, false, state.revealed, enemy_id)
	if combat.has_decoy():
		_add_decoy_pawn(combat.decoy_pos)


func _reconcile_battle_actors(sync_positions: bool) -> void:
	if combat == null or battle_actor_root == null:
		return
	var player := battle_actor_root.get_node_or_null("Player") as Node3D
	if player == null:
		_add_battle_pawn(combat.player_pos, true, true)
	elif sync_positions:
		player.position = _battle_pawn_world(combat.player_pos, true)
	var living: Dictionary = {}
	for enemy_id in combat.living_enemy_ids():
		living[enemy_id] = true
		var state = combat.enemy_by_id(enemy_id)
		var enemy_node := _enemy_node_for_id(enemy_id)
		if enemy_node == null:
			_add_battle_pawn(state.pos, false, state.revealed, enemy_id)
			enemy_node = _enemy_node_for_id(enemy_id)
		elif sync_positions:
			enemy_node.position = _battle_pawn_world(state.pos, false, enemy_id)
		if enemy_node != null:
			_refresh_enemy_node_visual(enemy_node, state)
	for raw_enemy_id in enemy_nodes.keys().duplicate():
		var enemy_id := str(raw_enemy_id)
		if living.has(enemy_id):
			continue
		var dead_node := enemy_nodes[raw_enemy_id] as Node3D
		if dead_node != null and is_instance_valid(dead_node):
			dead_node.free()
		enemy_nodes.erase(raw_enemy_id)
	var decoy := battle_actor_root.get_node_or_null("PaperDecoy") as Node3D
	if combat.has_decoy():
		if decoy == null:
			_add_decoy_pawn(combat.decoy_pos)
		elif sync_positions:
			decoy.position = _battle_world(combat.decoy_pos)
	elif decoy != null:
		decoy.free()


func _refresh_enemy_node_visual(node: Node3D, state) -> void:
	var presenter := node.get_node_or_null("Presenter")
	if presenter != null and presenter.has_method("set_obscured"):
		presenter.set_obscured(not state.revealed)
	_refresh_enemy_selection_outline(node, state)
	for child: Node in node.get_children():
		if child.name == "EnemyIntentBadge" or child.name == "EnemyIntent" or child.name == "EnemyIntentValue":
			child.free()


func update_battle_feedback_overlay() -> void:
	if battle_feedback_root == null:
		return
	if host.battle_feedback_suppressed:
		battle_feedback_root.visible = false
		for overlay_value: Variant in battle_intent_overlay_nodes.values():
			var hidden_overlay := overlay_value as Control
			if hidden_overlay != null:
				hidden_overlay.visible = false
		return
	var combat_feedback_enabled: bool = host.phase == "combat" and combat != null and combat.outcome == ""
	var intent_visible: bool = combat_feedback_enabled and _battle_debug_visible()
	var has_feedback_popups: bool = false
	for child: Node in battle_feedback_root.get_children():
		if child.name == "DamageFeedback" or child.name == "ActionCallout":
			has_feedback_popups = true
			break
	var has_queued_feedback := battle_feedback_playing or not battle_feedback_queue.is_empty()
	battle_feedback_root.visible = combat_feedback_enabled or has_feedback_popups or has_queued_feedback
	if not intent_visible:
		for overlay_value: Variant in battle_intent_overlay_nodes.values():
			var hidden_overlay := overlay_value as Control
			if hidden_overlay != null:
				hidden_overlay.visible = false
		return
	var active_ids: Dictionary = {}
	for raw_enemy_id in enemy_nodes.keys():
		var enemy_id := str(raw_enemy_id)
		var state = combat.enemy_by_id(enemy_id)
		var enemy_node := enemy_nodes[raw_enemy_id] as Node3D
		if state == null or enemy_node == null or int(state.hp) <= 0:
			continue
		active_ids[enemy_id] = true
		var overlay := battle_intent_overlay_nodes.get(enemy_id) as Control
		if overlay == null or not is_instance_valid(overlay):
			overlay = _create_battle_intent_overlay(enemy_id)
			battle_intent_overlay_nodes[enemy_id] = overlay
		overlay.visible = true
		_refresh_battle_intent_overlay(overlay, enemy_node, state)
	for raw_enemy_id in battle_intent_overlay_nodes.keys().duplicate():
		var stale_enemy_id := str(raw_enemy_id)
		if active_ids.has(stale_enemy_id):
			continue
		var stale_overlay := battle_intent_overlay_nodes[raw_enemy_id] as Control
		if stale_overlay != null and is_instance_valid(stale_overlay):
			stale_overlay.visible = false


func _create_battle_intent_overlay(enemy_id: String) -> Control:
	var overlay := Control.new()
	overlay.name = "EnemyIntentOverlay_%s" % enemy_id.replace("/", "_").replace(":", "_").replace(" ", "_")
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	battle_feedback_root.add_child(overlay)
	var badge := Panel.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ff9c4add")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	badge.add_theme_stylebox_override("panel", style)
	badge.set_meta("style_box", style)
	overlay.add_child(badge)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.add_child(icon)
	var value := Label.new()
	value.name = "Value"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_override("font", APP_FONT)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_color_override("font_outline_color", Color("14151d"))
	value.add_theme_constant_override("outline_size", 5)
	badge.add_child(value)
	return overlay


func _refresh_battle_intent_overlay(overlay: Control, enemy_node: Node3D, state) -> void:
	var intent_known: bool = state.revealed or _battle_enemy_intel_visible()
	var intent: Dictionary = battle_intent_snapshot.get(str(state.id), {})
	if intent.is_empty() and intent_known:
		intent = combat.preview_intent(state.id)
	if not intent_known:
		# 正式模式仍保留敌人的头顶提示位置，但不泄露攻击/移动类型、数值或方向。
		intent = {"type": "stall", "attack_kind": "", "intent_value": "？？"}
	var attack_kind := str(intent.get("attack_kind", ""))
	var intent_value := str(intent.get("intent_value", ""))
	var intent_color: Color = Color("77838c") if not intent_known else COL_RANGED_INTENT if attack_kind == "ranged" else _battle_intent_color(str(intent.get("type", "stall")))
	var pixels_per_world: float = host.world_view_rect.size.y / maxf(0.01, host.camera.size)
	var badge_size: Vector2 = Vector2(1.36, 0.86) * pixels_per_world if not intent_value.is_empty() else Vector2(0.86, 0.86) * pixels_per_world
	var floor_y := 0.39 + float(combat.heights.get(state.pos, 0)) * 0.64
	var anchor := enemy_node.global_position + Vector3.UP * (floor_y + 2.44)
	var screen_position := _battle_feedback_screen_position(anchor)
	if screen_position.x < -5000.0:
		overlay.visible = false
		return
	overlay.size = badge_size
	overlay.position = screen_position - badge_size * 0.5
	var badge := overlay.get_node("Badge") as Panel
	badge.size = badge_size
	var style := badge.get_meta("style_box") as StyleBoxFlat
	if style != null:
		style.bg_color = Color(intent_color, 0.87)
		var radius := maxi(3, roundi(pixels_per_world * 0.08))
		style.corner_radius_top_left = radius
		style.corner_radius_top_right = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
	var icon := badge.get_node("Icon") as TextureRect
	icon.texture = _battle_intent_icon_texture(str(intent.get("type", "stall")), attack_kind) if intent_known else null
	icon.visible = intent_known and icon.texture != null
	var icon_span: float = 0.70 * pixels_per_world
	icon.position = Vector2(0.08, 0.08) * pixels_per_world
	icon.size = Vector2(icon_span, icon_span)
	var value := badge.get_node("Value") as Label
	value.text = intent_value
	value.visible = not intent_value.is_empty()
	value.position = Vector2(0.72, 0.08) * pixels_per_world if intent_known else Vector2(0.08, 0.08) * pixels_per_world
	value.size = Vector2(0.54, 0.70) * pixels_per_world if intent_known else Vector2(0.84, 0.70) * pixels_per_world
	value.add_theme_font_size_override("font_size", maxi(12, roundi(40.0 * pixels_per_world * 0.012)))


func _refresh_enemy_selection_outline(node: Node3D, state) -> void:
	var existing: Node3D = node.get_node_or_null("EnemySelectionOutline") as Node3D
	var selected_enemy_id: String = _selected_battle_enemy_id()
	var should_show: bool = state != null and state.revealed and combat.outcome == "" and str(state.id) == selected_enemy_id
	if not should_show:
		if existing != null:
			existing.free()
		return
	if existing != null:
		return
	var floor_y := 0.39 + float(combat.heights.get(state.pos, 0)) * 0.64
	var outline := MeshInstance3D.new()
	outline.name = "EnemySelectionOutline"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.58
	ring.rings = 32
	ring.ring_segments = 10
	outline.mesh = ring
	outline.position = Vector3(0, floor_y + 0.08, 0)
	outline.material_override = _material(Color(COL_GOLD, 0.96), true, 0.22)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(outline)


func _selected_battle_enemy_id() -> String:
	if host.test_combat_active and not str(host.test_focused_enemy_id).is_empty():
		return str(host.test_focused_enemy_id)
	if not str(host.battle_focused_enemy_id).is_empty():
		return str(host.battle_focused_enemy_id)
	return str(host.test_focused_enemy_id)


func _focused_battle_enemy_id() -> String:
	if combat == null:
		return ""
	var focused_enemy_id := str(host.test_focused_enemy_id) if host.test_combat_active else str(host.battle_focused_enemy_id)
	if focused_enemy_id.is_empty():
		focused_enemy_id = str(host.battle_focused_enemy_id) if host.test_combat_active else str(host.test_focused_enemy_id)
	if not focused_enemy_id.is_empty() and battle_intent_snapshot.has(focused_enemy_id):
		return focused_enemy_id
	var hovered_enemy = combat.enemy_at(hovered_battle_cell)
	if hovered_enemy != null and battle_intent_snapshot.has(hovered_enemy.id):
		return hovered_enemy.id
	var visible_ranged: Array[String] = []
	for enemy_id in combat.living_enemy_ids():
		var intent: Dictionary = battle_intent_snapshot.get(enemy_id, {})
		if bool(intent.get("enemy_revealed", false)) and int(intent.get("attack_range", 0)) > 1:
			visible_ranged.append(enemy_id)
	return visible_ranged[0] if visible_ranged.size() == 1 else ""


func _is_valid_battle_target(pos: Vector2i) -> bool:
	if combat == null or combat.outcome != "":
		return false
	if selected_card < 0 and combat.energy <= 0 and combat.manhattan(combat.player_pos, pos) == 1:
		return true
	if selected_card >= 0:
		if selected_card >= combat.hand.size():
			return false
		return combat.can_target_place_card(selected_card, pos)
	var path: Array = combat.player_path_to(pos)
	return path.size() >= 2 and combat.player_path_cost(path) <= combat.energy


func _add_corner_marks(parent: Node3D, prefix: String, color: Color, y: float) -> void:
	var edge := BATTLE_CELL * 0.36
	for index in range(4):
		var sx := -1.0 if index % 2 == 0 else 1.0
		var sz := -1.0 if index < 2 else 1.0
		_add_box(parent, "%s_%d" % [prefix, index], Vector3(sx * edge, y, sz * edge), Vector3(0.28, 0.055, 0.28), _material(color, false, 0.08))


func _add_battle_floor_model(parent: Node3D, pos: Vector2i, footprint_active: bool) -> void:
	if not footprint_active:
		var mat := _add_box(parent, "BackstageCuttingMat", Vector3(0, 0.305, 0), Vector3(BATTLE_CELL - 0.055, 0.075, BATTLE_CELL - 0.055), _material(Color("315f51")))
		mat.set_meta("battle_backstage", true)
		mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var line_color := Color("9bb59b88")
		_add_box(parent, "MatGridX", Vector3(0, 0.347, 0), Vector3(BATTLE_CELL - 0.16, 0.012, 0.025), _material(line_color, true))
		_add_box(parent, "MatGridZ", Vector3(0, 0.348, 0), Vector3(0.025, 0.012, BATTLE_CELL - 0.16), _material(line_color, true))
		if posmod(pos.x * 13 + pos.y * 7, 5) == 0:
			var tape := _add_box(parent, "BackstageTape", Vector3(0.36, 0.356, -0.36), Vector3(0.46, 0.014, 0.085), _material(Color("e6bd4ba8"), true))
			tape.rotation.y = PI * 0.25
		return
	_add_battle_timber_tiles(parent, pos, BATTLE_FLOOR_LIGHT, 0.305, "RoomFloor_%d_%d" % [pos.x, pos.y], "house_floor_spec")


func _add_battle_timber_tiles(parent: Node3D, pos: Vector2i, floor_path: String, floor_y: float, root_name: String, meta_key: String = "") -> Node3D:
	var packed := load(floor_path) as PackedScene
	if packed == null:
		return null
	var floor_root := Node3D.new()
	floor_root.name = root_name
	if not meta_key.is_empty():
		floor_root.set_meta(meta_key, true)
	parent.add_child(floor_root)
	var probe := packed.instantiate() as Node3D
	if probe == null:
		floor_root.queue_free()
		return null
	probe.name = "TimberTile_0_0"
	floor_root.add_child(probe)
	var bounds := _node_visual_aabb_in_parent(floor_root, probe)
	if bounds.size == Vector3.ZERO:
		probe.position.y = floor_y
		probe.scale = Vector3.ONE * (BATTLE_CELL / 4.0)
	else:
		var target_span := BATTLE_CELL - 0.08
		var uniform_scale := target_span / maxf(bounds.size.x, bounds.size.z)
		var tile_span_x := bounds.size.x * uniform_scale
		var tile_span_z := bounds.size.z * uniform_scale
		var tiles_x := clampi(ceili(target_span / maxf(tile_span_x, 0.01) - 0.01), 1, 3)
		var tiles_z := clampi(ceili(target_span / maxf(tile_span_z, 0.01) - 0.01), 1, 3)
		for tile_z in range(tiles_z):
			for tile_x in range(tiles_x):
				var floor_model := probe if tile_x == 0 and tile_z == 0 else packed.instantiate() as Node3D
				if floor_model == null:
					continue
				if floor_model != probe:
					floor_root.add_child(floor_model)
				floor_model.name = "TimberTile_%d_%d" % [tile_x, tile_z]
				floor_model.scale = Vector3.ONE * uniform_scale
				var tile_center_x := (float(tile_x) - float(tiles_x - 1) * 0.5) * tile_span_x
				var tile_center_z := (float(tile_z) - float(tiles_z - 1) * 0.5) * tile_span_z
				floor_model.position = Vector3(
					tile_center_x - (bounds.position.x + bounds.size.x * 0.5) * uniform_scale,
					floor_y - bounds.position.y * uniform_scale,
					tile_center_z - (bounds.position.z + bounds.size.z * 0.5) * uniform_scale
				)
	for child: Node in floor_root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return floor_root


func _apply_battle_footprint_to_combat() -> void:
	battle_backstage_cells.clear()
	battle_height_prop_assignments.clear()
	battle_blocker_prop_assignments.clear()
	battle_height_visual_indices.clear()
	if combat == null:
		return
	for y in range(combat.rows):
		for x in range(combat.cols):
			var cell := Vector2i(x, y)
			if _battle_cell_in_room_footprint(cell):
				continue
			battle_backstage_cells[cell] = true
	# Preserve authored arena mechanics by moving anything that landed in a
	# clipped footprint corner to the nearest active cell before sealing the
	# backstage area.
	var reserved_walls: Dictionary = {}
	var original_walls: Array = combat.walls.keys().duplicate()
	combat.walls.clear()
	for raw_cell: Variant in original_walls:
		var source := raw_cell as Vector2i
		var target := source if not battle_backstage_cells.has(source) else _nearest_active_battle_cell(source, INVALID_CELL, reserved_walls)
		if target != INVALID_CELL:
			combat.walls[target] = true
			reserved_walls[target] = true
	var relocated_heights: Dictionary = {}
	var original_height_cells: Array = combat.heights.keys().duplicate()
	for raw_cell: Variant in original_height_cells:
		var source := raw_cell as Vector2i
		var height := int(combat.heights.get(source, 0))
		var target := source
		if battle_backstage_cells.has(source) or combat.walls.has(source) or relocated_heights.has(source):
			var reserved := reserved_walls.duplicate()
			for occupied: Variant in relocated_heights.keys():
				reserved[occupied] = true
			target = _nearest_active_battle_cell(source, INVALID_CELL, reserved)
		if target != INVALID_CELL:
			relocated_heights[target] = height
	combat.heights = relocated_heights
	var portal_pairs: Array[Array] = []
	var seen_portals: Dictionary = {}
	for raw_cell: Variant in combat.portals.keys():
		var a := raw_cell as Vector2i
		var b: Vector2i = combat.portals.get(a, INVALID_CELL)
		var pair_key := "%s|%s" % [str(a if a.x < b.x or (a.x == b.x and a.y <= b.y) else b), str(b if a.x < b.x or (a.x == b.x and a.y <= b.y) else a)]
		if seen_portals.has(pair_key):
			continue
		seen_portals[pair_key] = true
		portal_pairs.append([a, b])
	combat.portals.clear()
	for pair: Array in portal_pairs:
		var reserved := reserved_walls.duplicate()
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		if battle_backstage_cells.has(a) or combat.walls.has(a):
			a = _nearest_active_battle_cell(a, INVALID_CELL, reserved)
		reserved[a] = true
		if battle_backstage_cells.has(b) or combat.walls.has(b) or b == a:
			b = _nearest_active_battle_cell(b, a, reserved)
		if a != INVALID_CELL and b != INVALID_CELL and a != b:
			combat.portals[a] = b
			combat.portals[b] = a
	for raw_cell: Variant in battle_backstage_cells.keys():
		var cell := raw_cell as Vector2i
		combat.walls[cell] = true
		combat.traps.erase(cell)
	if battle_backstage_cells.has(combat.player_pos) or not combat.is_walkable(combat.player_pos):
		combat.player_pos = _nearest_active_battle_cell(combat.player_pos)
	var reserved_enemy_cells: Dictionary = {}
	for enemy_id in combat.enemy_order:
		var enemy_state = combat.enemy_by_id(enemy_id)
		if enemy_state == null:
			continue
		if battle_backstage_cells.has(enemy_state.pos) or not combat.is_walkable(enemy_state.pos) or enemy_state.pos == combat.player_pos or reserved_enemy_cells.has(enemy_state.pos):
			enemy_state.pos = _nearest_active_battle_cell(enemy_state.pos, combat.player_pos, reserved_enemy_cells)
		if enemy_state.pos != INVALID_CELL:
			reserved_enemy_cells[enemy_state.pos] = enemy_id
	combat._refresh_vision(false)


func _nearest_active_battle_cell(origin: Vector2i, forbidden: Vector2i = INVALID_CELL, reserved: Dictionary = {}) -> Vector2i:
	var best := INVALID_CELL
	var best_score := INF
	for y in range(combat.rows):
		for x in range(combat.cols):
			var candidate := Vector2i(x, y)
			if candidate == forbidden or reserved.has(candidate) or not _battle_cell_in_room_footprint(candidate) or not combat.is_walkable(candidate):
				continue
			var score := float(absi(candidate.x - origin.x) + absi(candidate.y - origin.y))
			if score < best_score:
				best = candidate
				best_score = score
	return best


func _prepare_battle_prop_assignments() -> void:
	battle_height_prop_assignments.clear()
	battle_blocker_prop_assignments.clear()
	battle_height_visual_indices.clear()
	if combat == null:
		return
	var props: Array = battle_room_context.get("props", [])
	var used_height_props: Dictionary = {}
	var height_sequence_counts: Dictionary = {}
	var height_cells: Array = combat.heights.keys()
	height_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for raw_cell: Variant in height_cells:
		var cell := raw_cell as Vector2i
		var height := int(combat.heights.get(cell, 0))
		battle_height_visual_indices[cell] = int(height_sequence_counts.get(height, 0))
		height_sequence_counts[height] = int(height_sequence_counts.get(height, 0)) + 1
		var target := _battle_cell_normalized(cell)
		var best_index := -1
		var best_distance := INF
		for prop_index in range(props.size()):
			if used_height_props.has(prop_index):
				continue
			var record := props[prop_index] as Dictionary
			if int(record.get("height_class", 0)) != height:
				continue
			var normalized := record.get("normalized", []) as Array
			if normalized.size() < 2:
				continue
			var distance := target.distance_squared_to(Vector2(float(normalized[0]), float(normalized[1])))
			if distance < best_distance:
				best_index = prop_index
				best_distance = distance
		if best_index >= 0:
			battle_height_prop_assignments[cell] = (props[best_index] as Dictionary).duplicate(true)
			used_height_props[best_index] = true
	var used_blocker_props: Dictionary = {}
	var wall_cells: Array = combat.walls.keys()
	wall_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for raw_cell: Variant in wall_cells:
		var cell := raw_cell as Vector2i
		if battle_backstage_cells.has(cell):
			continue
		var target := _battle_cell_normalized(cell)
		var best_index := -1
		var best_distance := INF
		for prop_index in range(props.size()):
			if used_blocker_props.has(prop_index):
				continue
			var record := props[prop_index] as Dictionary
			if not bool(record.get("battle_blocker", false)):
				continue
			var normalized := record.get("normalized", []) as Array
			if normalized.size() < 2:
				continue
			var distance := target.distance_squared_to(Vector2(float(normalized[0]), float(normalized[1])))
			if distance < best_distance:
				best_index = prop_index
				best_distance = distance
		if best_index >= 0:
			battle_blocker_prop_assignments[cell] = (props[best_index] as Dictionary).duplicate(true)
			used_blocker_props[best_index] = true


func _battle_cell_normalized(pos: Vector2i) -> Vector2:
	return Vector2(
		(float(pos.x) + 0.5) / maxf(1.0, float(combat.cols)),
		(float(pos.y) + 0.5) / maxf(1.0, float(combat.rows))
	)


func _align_battle_terrain_to_room_context() -> void:
	if combat == null or combat.heights.is_empty():
		return
	var height_values: Array[int] = []
	var original_positions: Array[Vector2i] = []
	for raw_pos: Variant in combat.heights.keys():
		var height := int(combat.heights[raw_pos])
		if height <= 0:
			continue
		height_values.append(height)
		original_positions.append(raw_pos as Vector2i)
	height_values.sort()
	height_values.reverse()
	var props := (battle_room_context.get("props", []) as Array).duplicate(true)
	var used_props := {}
	var used_cells := {}
	combat.heights.clear()
	for index in range(height_values.size()):
		var height := height_values[index]
		var chosen_prop := -1
		for prop_index in range(props.size()):
			if used_props.has(prop_index):
				continue
			if int((props[prop_index] as Dictionary).get("height_class", 0)) == height:
				chosen_prop = prop_index
				break
		var preferred := original_positions[index] if index < original_positions.size() else Vector2i(combat.cols / 2, combat.rows / 2)
		if chosen_prop >= 0:
			used_props[chosen_prop] = true
			var normalized := (props[chosen_prop] as Dictionary).get("normalized", []) as Array
			if normalized.size() >= 2:
				preferred = Vector2i(
					clampi(floori(float(normalized[0]) * float(combat.cols)), 0, combat.cols - 1),
					clampi(floori(float(normalized[1]) * float(combat.rows)), 0, combat.rows - 1)
				)
		var target := _nearest_battle_layout_cell(preferred, used_cells)
		if target.x < 0:
			continue
		used_cells[target] = true
		combat.heights[target] = height
	if combat.has_method("_refresh_vision"):
		combat._refresh_vision(false)


func _nearest_battle_layout_cell(preferred: Vector2i, used_cells: Dictionary) -> Vector2i:
	var best := INVALID_CELL
	var best_score := INF
	for y in range(combat.rows):
		for x in range(combat.cols):
			var candidate := Vector2i(x, y)
			if used_cells.has(candidate) or combat.walls.has(candidate) or combat.portals.has(candidate):
				continue
			if candidate == combat.player_pos or combat.enemy_at(candidate) != null:
				continue
			var footprint_penalty := 1000.0 if not _battle_cell_in_room_footprint(candidate) else 0.0
			var score := float(abs(candidate.x - preferred.x) + abs(candidate.y - preferred.y)) + footprint_penalty
			if score < best_score:
				best_score = score
				best = candidate
	return best


func _battle_cell_in_room_footprint(pos: Vector2i) -> bool:
	var raw_cells := battle_room_context.get("footprint", []) as Array
	if raw_cells.is_empty() or combat == null:
		return true
	var footprint_cells: Array[Vector2i] = []
	var min_cell := Vector2i(9999, 9999)
	var max_cell := Vector2i(-9999, -9999)
	for raw_cell: Variant in raw_cells:
		if not raw_cell is Array or (raw_cell as Array).size() < 2:
			continue
		var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		footprint_cells.append(cell)
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))
	if footprint_cells.is_empty():
		return true
	var width := max_cell.x - min_cell.x + 1
	var height := max_cell.y - min_cell.y + 1
	var mapped := Vector2i(
		min_cell.x + mini(width - 1, floori((float(pos.x) + 0.5) / float(combat.cols) * float(width))),
		min_cell.y + mini(height - 1, floori((float(pos.y) + 0.5) / float(combat.rows) * float(height)))
	)
	return mapped in footprint_cells


func _add_battle_height_asset(parent: Node3D, pos: Vector2i, height: int, logical_top_y: float) -> void:
	var inherited := _battle_context_prop_for_cell(pos, height)
	var asset_path := str(inherited.get("path", ""))
	if asset_path.is_empty() and height == 1:
		_add_battle_raised_deck(parent, pos, logical_top_y)
		_add_battle_walkable_top_marker(parent, logical_top_y)
		return
	if asset_path.is_empty():
		var options: Array = _battle_height_asset_options(height)
		if options.is_empty():
			return
		var visual_index := int(battle_height_visual_indices.get(pos, pos.x * 17 + pos.y * 31))
		var asset_name := str(options[posmod(visual_index, options.size())])
		asset_path = asset_name if asset_name.begins_with("res://") else BATTLE_HEIGHT_ASSET_ROOT + asset_name
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return
	prop.name = "TerrainAsset_H%d_%s" % [height, asset_path.get_file().get_basename()]
	if not inherited.is_empty():
		prop.set_meta("battle_context_prop", true)
		prop.set_meta("source_asset_id", str(inherited.get("asset_id", "")))
	prop.position = Vector3.ZERO
	prop.rotation.y = float(inherited.get("yaw", float(posmod(pos.x + pos.y, 4)) * PI * 0.5))
	prop.scale = Vector3.ONE
	parent.add_child(prop)
	var visual_bounds := _node_visual_aabb_in_parent(parent, prop)
	if visual_bounds.size != Vector3.ZERO:
		var target_height := maxf(0.42, logical_top_y - 0.24)
		var target_width := BATTLE_CELL - 0.30
		var height_scale := target_height / maxf(visual_bounds.size.y, 0.01)
		var width_scale := target_width / maxf(maxf(visual_bounds.size.x, visual_bounds.size.z), 0.01)
		var fitted_scale := minf(height_scale, width_scale)
		prop.scale = Vector3.ONE * fitted_scale
		prop.position.y = 0.29 - visual_bounds.position.y * fitted_scale
	else:
		prop.position = Vector3(0, 0.31, 0)
		prop.scale = Vector3.ONE * (0.43 if height == 1 else 0.46)
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_battle_miniature_finish(prop, str(inherited.get("asset_id", asset_path.get_file().get_basename())))
	_add_battle_walkable_top_marker(parent, logical_top_y)


func _add_battle_raised_deck(parent: Node3D, pos: Vector2i, logical_top_y: float) -> void:
	var deck_bottom := logical_top_y - 0.16
	var deck := _add_battle_timber_tiles(parent, pos, BATTLE_FLOOR_DARK, deck_bottom, "RaisedTimberDeck", "battle_raised_deck")
	if deck == null:
		return
	var support_height := maxf(0.12, deck_bottom - 0.31)
	var support_color: Color = battle_room_context.get("rim", Color("66564d"))
	var offset := BATTLE_CELL * 0.37
	for index in range(4):
		var sx := -1.0 if index % 2 == 0 else 1.0
		var sz := -1.0 if index < 2 else 1.0
		_add_box(parent, "DeckLeg_%d" % index, Vector3(sx * offset, 0.31 + support_height * 0.5, sz * offset), Vector3(0.13, support_height, 0.13), _material(support_color.darkened(0.18)))
	var brace_y := 0.31 + support_height * 0.45
	var brace_x := _add_box(parent, "DeckBraceX", Vector3(0, brace_y, 0), Vector3(BATTLE_CELL * 0.72, 0.075, 0.075), _material(support_color.darkened(0.08)))
	brace_x.rotation.z = -0.12 if posmod(pos.x + pos.y, 2) == 0 else 0.12
	var tape := _add_box(parent, "DeckTape", Vector3(BATTLE_CELL * 0.25, logical_top_y - 0.02, -BATTLE_CELL * 0.36), Vector3(0.44, 0.018, 0.075), _material(Color("e5d49dcc"), true))
	tape.rotation.y = PI * 0.07


func _add_battle_walkable_top_marker(parent: Node3D, logical_top_y: float) -> void:
	var top_marker := _add_box(parent, "WalkableAssetTop", Vector3(0, logical_top_y - 0.075, 0), Vector3(BATTLE_CELL - 0.46, 0.055, BATTLE_CELL - 0.46), _material(Color(COL_GOLD, 0.02), true, 0.0))
	top_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_marker.visible = false


func _add_battle_blocker_asset(parent: Node3D, pos: Vector2i, platform_height: float) -> void:
	var inherited: Dictionary = battle_blocker_prop_assignments.get(pos, {})
	var asset_path := str(inherited.get("path", ""))
	if asset_path.is_empty():
		var options: Array = BATTLE_BLOCKER_ASSETS
		if options.is_empty():
			return
		var raw_path := str(options[posmod(pos.x * 19 + pos.y * 23, options.size())])
		asset_path = raw_path if raw_path.begins_with("res://") else BATTLE_HEIGHT_ASSET_ROOT + raw_path
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	if prop == null:
		return
	prop.name = "BlockerAsset_%s" % asset_path.get_file().get_basename()
	if not inherited.is_empty():
		prop.set_meta("battle_context_prop", true)
		prop.set_meta("source_asset_id", str(inherited.get("asset_id", "")))
	prop.rotation.y = float(inherited.get("yaw", float(posmod(pos.x + pos.y, 4)) * PI * 0.5))
	parent.add_child(prop)
	var bounds := _node_visual_aabb_in_parent(parent, prop)
	if bounds.size != Vector3.ZERO:
		var fitted_scale := minf(1.58 / maxf(bounds.size.y, 0.01), (BATTLE_CELL - 0.30) / maxf(maxf(bounds.size.x, bounds.size.z), 0.01))
		prop.scale = Vector3.ONE * fitted_scale
		prop.position.y = platform_height + 0.08 - bounds.position.y * fitted_scale
	else:
		prop.scale = Vector3.ONE * 0.46
		prop.position.y = platform_height + 0.08
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_apply_battle_miniature_finish(prop, str(inherited.get("asset_id", asset_path.get_file().get_basename())))


func _battle_context_prop_for_cell(pos: Vector2i, height: int) -> Dictionary:
	var record: Dictionary = battle_height_prop_assignments.get(pos, {})
	return record if int(record.get("height_class", 0)) == height else {}


func _battle_height_asset_options(height: int) -> Array:
	var inherited: Array = []
	var themed: Dictionary = battle_room_context.get("height_assets", {})
	var options: Array = themed.get(height, [])
	for raw_path: Variant in options:
		var themed_path := str(raw_path)
		if themed_path not in inherited:
			inherited.append(themed_path)
	if not inherited.is_empty():
		return inherited
	return (BATTLE_HEIGHT_ASSETS.get(height, []) as Array).duplicate()


func _node_visual_aabb_in_parent(parent: Node3D, model: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var to_parent := parent.global_transform.affine_inverse()
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box := (to_parent * mesh_instance.global_transform) * mesh_instance.get_aabb()
		result = result.merge(box) if has_bounds else box
		has_bounds = true
	return result if has_bounds else AABB()


func _apply_battle_miniature_finish(model: Node3D, asset_id: String) -> void:
	var finish := RoomPropCatalog.handmade_finish_for(asset_id)
	var tint := RoomPropCatalog.handmade_tint_for(asset_id)
	var tint_strength := 0.16 if finish == "painted_wood" else 0.20
	for raw_mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_surface_override_material(surface_index)
			if source == null:
				source = mesh_instance.mesh.surface_get_material(surface_index)
			if not source is StandardMaterial3D:
				continue
			var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
			var target := tint
			target.a = material.albedo_color.a
			material.albedo_color = material.albedo_color.lerp(target, tint_strength)
			material.roughness = maxf(material.roughness, 0.88 if finish == "painted_wood" else 0.94)
			material.metallic = minf(material.metallic, 0.03)
			mesh_instance.set_surface_override_material(surface_index, material)
	model.set_meta("miniature_finish", finish)


func _add_portal_marker(parent: Node3D, pos: Vector2i, y: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "PortalRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.50
	mesh.outer_radius = 0.72
	ring.mesh = mesh
	ring.position = Vector3(0, y + 0.15, 0)
	ring.material_override = _material(Color("9a70da"), false, 0.14)
	parent.add_child(ring)
	_add_label(parent, "PortalLabel", _portal_endpoint_label(pos), Vector3(0, y + 0.23, 0), Color("f4ecff"), 22)


func _portal_endpoint_label(pos: Vector2i) -> String:
	if not combat.portals.has(pos):
		return ""
	var other: Vector2i = combat.portals[pos]
	return "A" if pos.x < other.x or (pos.x == other.x and pos.y < other.y) else "B"


func _add_battle_pawn(pos: Vector2i, is_player: bool, revealed: bool, enemy_id: String = "") -> void:
	var node := Node3D.new()
	var node_name := "Player"
	if not is_player:
		node_name = _enemy_node_name(enemy_id)
	node.name = node_name
	node.position = _battle_pawn_world(pos, is_player, enemy_id)
	node.rotation.y = battle_player_facing_yaw if is_player else battle_enemy_facing_yaw
	battle_actor_root.add_child(node)
	if not is_player:
		enemy_nodes[enemy_id] = node
	var floor_y := 0.39 + float(combat.heights.get(pos, 0)) * 0.64
	var enemy_state = combat.enemy_by_id(enemy_id) if not is_player else null
	var is_ranged_enemy: bool = enemy_state != null and enemy_state.has_trait("ranged")
	var is_backstab_enemy: bool = enemy_state != null and enemy_state.has_trait("backstab")
	var is_webber_enemy: bool = enemy_state != null and enemy_state.has_trait("webber")
	var visible_enemy_color: Color = COL_BACKSTAB_ENEMY if is_backstab_enemy else COL_RANGED_ENEMY if is_ranged_enemy else COL_WEB if is_webber_enemy else COL_RED
	var base_color: Color = COL_TEAL if is_player else visible_enemy_color if revealed else Color("1f2930")
	_add_cylinder(node, "PawnBase", Vector3(0, floor_y + 0.026, 0), 0.46, 0.052, _material(Color(base_color, 0.58), true, 0.035))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0, floor_y + 0.05, 0)
	node.add_child(presenter)
	var actor_key := "player" if is_player else "enemy"
	var presenter_id := actor_key if is_player else "%s:%s" % [actor_key, str(enemy_state.archetype if enemy_state != null else combat.enemy_archetype)]
	presenter.configure(presenter_id, _battle_actor_presentation(actor_key, enemy_id))
	presenter.state_changed.connect(_on_presenter_state_changed)
	if not is_player:
		presenter.set_obscured(not revealed)
	if not is_player and enemy_state != null:
		_refresh_enemy_node_visual(node, enemy_state)


func _battle_intent_color(intent_type: String) -> Color:
	match intent_type:
		"attack": return Color("ff5a4e")
		"chase": return Color("ff9c4a")
		"web": return COL_WEB
		"wait": return Color("f2a51e")
		"search": return Color("6ab7e8")
		"patrol": return Color("5fd6c6")
		"ambush": return Color("e06bb4")
	return Color("c8d4d8")


func _battle_intent_glyph(intent_type: String, attack_kind: String = "") -> String:
	match intent_type:
		"attack":
			if attack_kind == "ranged":
				return "远"
			if attack_kind == "beam":
				return "束"
			return "攻"
		"web": return "网"
		"chase": return "追"
		"wait": return "待"
		"search": return "搜"
		"patrol": return "巡"
		"ambush": return "伏"
	return "待"


func _battle_facing_glyph(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "↑"
	if direction == Vector2i.RIGHT:
		return "→"
	if direction == Vector2i.DOWN:
		return "↓"
	if direction == Vector2i.LEFT:
		return "←"
	return "·"


func _battle_intent_icon_texture(intent_type: String, attack_kind: String = "") -> Texture2D:
	# “等待”暂时复用移动图标，等专用绕后等待图标制作完成后再替换。
	if intent_type == "wait":
		return INTENT_MOVE_ICON
	if intent_type == "web":
		return INTENT_MOVE_ICON
	if attack_kind == "ranged":
		return INTENT_RANGED_ICON
	if attack_kind in ["beam", "melee", "lunge", "guardBreak", "slam", "faceShock", "decoy"] or intent_type in ["attack", "ambush"]:
		return INTENT_ATTACK_ICON
	return INTENT_MOVE_ICON


func _battle_actor_presentation(actor_key: String, enemy_id: String = "") -> Dictionary:
	var actors: Dictionary = presentation.get("actors", {})
	var config: Dictionary = (actors.get(actor_key, {}) as Dictionary).duplicate(true)
	if actor_key != "enemy" or combat == null:
		return config
	var archetypes: Dictionary = presentation.get("enemy_archetypes", {})
	var state = combat.enemy_by_id(enemy_id) if enemy_id != "" else null
	var archetype: String = str(state.archetype) if state != null else combat.enemy_archetype
	var variant: Dictionary = archetypes.get(archetype, {})
	config.merge(variant, true)
	if state != null and state.has_trait("backstab"):
		# 背刺敌人用黑色 tint 与黑色底座区分，仍复用已验证的动画模型。
		config["model_tint"] = COL_BACKSTAB_ENEMY
		config["model_tint_strength"] = 0.78
	elif state != null and state.has_trait("ranged"):
		# 远程敌人沿用原模型和贴图，只通过材质 tint 与底座颜色做识别。
		config["model_tint"] = COL_RANGED_ENEMY
		config["model_tint_strength"] = 0.55
	elif state != null and state.has_trait("webber"):
		config["model_tint"] = COL_WEB
		config["model_tint_strength"] = 0.58
	return config


func _battle_pawn_world(pos: Vector2i, is_player: bool, enemy_id: String = "") -> Vector3:
	var world := _battle_world(pos)
	if combat != null and pos == combat.player_pos and combat.enemy_at(pos) != null:
		if is_player:
			world += Vector3(-0.30, 0.0, 0.20)
		else:
			world += Vector3(0.30, 0.0, -0.20)
	return world


func _enemy_node_name(enemy_id: String) -> String:
	if combat != null and not combat.enemy_order.is_empty() and enemy_id == combat.enemy_order[0]:
		return "Enemy"
	var safe_id := enemy_id.replace("/", "_").replace(":", "_").replace(" ", "_")
	return "Enemy_%s" % safe_id


func _enemy_node_for_id(enemy_id: String) -> Node3D:
	var node := enemy_nodes.get(enemy_id) as Node3D
	if node != null and is_instance_valid(node):
		return node
	return null


func _enemy_state_for_node(node: Node3D):
	for enemy_id in enemy_nodes.keys():
		if enemy_nodes[enemy_id] == node and combat != null:
			return combat.enemy_by_id(str(enemy_id))
	return null


func _play_enemy_state(enemy_id: String, state: String, callout: String = "") -> void:
	battle_turn_actor_id = enemy_id
	if hud != null:
		hud.queue_redraw()
	var node := _enemy_node_for_id(enemy_id)
	if node == null:
		return
	var presenter := node.get_node_or_null("Presenter")
	if presenter != null and presenter.has_method("play_state"):
		presenter.play_state(state, callout)


func _show_enemy_damage_feedback(enemy_id: String, damage: int) -> void:
	_show_actor_damage_feedback(_enemy_node_name(enemy_id), damage)


func _show_enemy_callout_feedback(enemy_id: String, text: String) -> void:
	_show_actor_callout_feedback(_enemy_node_name(enemy_id), text)


func _is_salt_ring_event(event: Dictionary) -> bool:
	var trap_value: Variant = event.get("trap", {})
	var trap: Dictionary = trap_value if trap_value is Dictionary else {}
	var card_id := str(trap.get("card_id", event.get("card_id", "")))
	return card_id == "salt" or card_id == "guard"


func _salt_ring_hit_frames() -> SpriteFrames:
	if salt_ring_hit_frames != null:
		return salt_ring_hit_frames
	var frames := SpriteFrames.new()
	frames.add_animation("salt_ring")
	frames.set_animation_speed("salt_ring", 12.0)
	frames.set_animation_loop("salt_ring", false)
	var sheet := SALT_RING_HIT_SHEET.get_image()
	var sheet_width := sheet.get_width()
	var sheet_height := sheet.get_height()
	for frame_index in range(9):
		var column := frame_index % 3
		var row := frame_index / 3
		var left := column * sheet_width / 3
		var top := row * sheet_height / 3
		var right := (column + 1) * sheet_width / 3
		var bottom := (row + 1) * sheet_height / 3
		var frame := sheet.get_region(Rect2i(left, top, right - left, bottom - top))
		frame.convert(Image.FORMAT_RGBA8)
		var edge_band := 4
		for y in range(frame.get_height()):
			for x in range(frame.get_width()):
				var color := frame.get_pixel(x, y)
				# The imported sheet keeps a visible separator on each cell edge;
				# discard a small safety band so no vertical/horizontal bar survives
				# when the frame is displayed with alpha blending.
				if x < edge_band or y < edge_band or x >= frame.get_width() - edge_band or y >= frame.get_height() - edge_band:
					frame.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
					continue
				var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
				# The source sheet contains gray cell separators in addition to its
				# black background. A higher threshold removes both, while keeping
				# the cream-colored drawing and its soft antialiased edge.
				var ink_alpha := smoothstep(0.24, 0.34, luminance)
				frame.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * ink_alpha))
		frames.add_frame("salt_ring", ImageTexture.create_from_image(frame))
	salt_ring_hit_frames = frames
	return salt_ring_hit_frames


func _show_enemy_salt_ring_effect(enemy_id: String) -> void:
	var actor := _enemy_node_for_id(enemy_id)
	if actor == null:
		return
	var state = combat.enemy_by_id(enemy_id) if combat != null else null
	if state != null and not state.revealed:
		return
	_show_salt_ring_effect(actor)


func _show_player_salt_ring_effect() -> void:
	var root: Node3D = battle_actor_root
	if root == null:
		return
	var actor := root.get_node_or_null("Player") as Node3D
	_show_salt_ring_effect(actor)


func _show_salt_ring_effect(actor: Node3D) -> void:
	if actor == null:
		return
	var existing := actor.get_node_or_null("SaltRingHitEffect")
	if existing != null:
		existing.queue_free()
	var effect := AnimatedSprite3D.new()
	effect.name = "SaltRingHitEffect"
	effect.sprite_frames = _salt_ring_hit_frames()
	effect.animation = "salt_ring"
	effect.position = Vector3(0, 2.22, 0.08)
	effect.pixel_size = 0.00425
	effect.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	effect.shaded = false
	effect.no_depth_test = true
	effect.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# SpriteBase3D 的合法优先级上限是 127；使用上限保证序列帧
	# 在无深度测试时仍稳定位于战斗反馈层，而不是触发渲染器警告。
	effect.render_priority = 127
	effect.modulate = Color("fff0c9")
	actor.add_child(effect)
	effect.animation_finished.connect(func() -> void:
		if is_instance_valid(effect):
			effect.queue_free()
	)
	effect.play("salt_ring")


func _add_decoy_pawn(pos: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "PaperDecoy"
	node.position = _battle_world(pos)
	battle_actor_root.add_child(node)
	var floor_y := 0.39 + float(combat.heights.get(pos, 0)) * 0.64
	_add_cylinder(node, "PaperBase", Vector3(0, floor_y + 0.06, 0), 0.42, 0.10, _material(Color("d5b97a")))
	_add_box(node, "PaperBody", Vector3(0, floor_y + 0.72, 0), Vector3(0.72, 1.22, 0.10), _material(Color("efe0b9")))
	var cross := _add_box(node, "PaperCross", Vector3(0, floor_y + 0.77, 0), Vector3(0.10, 1.05, 0.68), _material(Color("efe0b9")))
	cross.rotation.y = PI * 0.5
	_add_label(node, "PaperGlyph", "影", Vector3(0, floor_y + 1.48, 0), COL_MAGENTA, 34)


func _play_actor_state(actor_node_name: String, state: String, callout: String = "") -> void:
	var presenter: Node = battle_actor_root.get_node_or_null("%s/Presenter" % actor_node_name)
	if presenter != null and presenter.has_method("play_state"):
		presenter.play_state(state, callout)


func _show_actor_damage_feedback(actor_node_name: String, damage: int) -> void:
	if damage <= 0:
		return
	_enqueue_actor_feedback(actor_node_name, "damage", damage)


func _show_actor_callout_feedback(actor_node_name: String, text: String) -> void:
	if text.is_empty():
		return
	_enqueue_actor_feedback(actor_node_name, "callout", text)


func _enqueue_actor_feedback(actor_node_name: String, feedback_kind: String, value: Variant) -> void:
	if battle_feedback_root == null:
		return
	battle_feedback_queue.append({
		"actor": actor_node_name,
		"kind": feedback_kind,
		"value": value,
	})
	_drain_actor_feedback_queue()


func _drain_actor_feedback_queue() -> void:
	if battle_feedback_playing or battle_feedback_queue.is_empty():
		return
	battle_feedback_playing = true
	var entry: Dictionary = battle_feedback_queue.pop_front()
	var generation: int = battle_feedback_generation
	var feedback_tween: Tween = _play_actor_feedback_entry(entry)
	if feedback_tween == null:
		_finish_actor_feedback(generation)
		return
	feedback_tween.finished.connect(_finish_actor_feedback.bind(generation), CONNECT_ONE_SHOT)


func _finish_actor_feedback(generation: int) -> void:
	if generation != battle_feedback_generation:
		return
	battle_feedback_playing = false
	_drain_actor_feedback_queue()


func _play_actor_feedback_entry(entry: Dictionary) -> Tween:
	var actor_node_name := str(entry.get("actor", ""))
	var feedback_kind := str(entry.get("kind", ""))
	if feedback_kind == "damage":
		return _play_actor_damage_feedback(actor_node_name, int(entry.get("value", 0)))
	elif feedback_kind == "callout":
		return _play_actor_callout_feedback(actor_node_name, str(entry.get("value", "")))
	return null


func _play_actor_damage_feedback(actor_node_name: String, damage: int) -> Tween:
	var actor := battle_actor_root.get_node_or_null(actor_node_name) as Node3D
	if actor == null or damage <= 0 or battle_feedback_root == null:
		return
	var popup := Label.new()
	popup.name = "DamageFeedback"
	popup.text = "✦  -%d  ✦" % damage
	popup.size = Vector2(170, 54)
	popup.position = _battle_feedback_screen_position(actor.global_position + Vector3.UP * 1.28) - popup.size * 0.5
	popup.pivot_offset = popup.size * 0.5
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_override("font", APP_FONT)
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_color_override("font_color", Color("ff4e61"))
	popup.add_theme_color_override("font_outline_color", Color("fff2d2"))
	popup.add_theme_constant_override("outline_size", 6)
	popup.modulate = Color("ff4e61")
	popup.z_index = 200
	popup.scale = Vector2(0.35, 0.35)
	battle_feedback_root.add_child(popup)
	var base_actor_position := actor.position
	var feedback := actor.create_tween()
	feedback.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	feedback.tween_property(actor, "position", base_actor_position + Vector3(-0.18, 0.05, 0), 0.055)
	feedback.tween_property(actor, "position", base_actor_position + Vector3(0.16, 0.0, 0), 0.055)
	feedback.tween_property(actor, "position", base_actor_position, 0.09)
	feedback.parallel().tween_property(actor, "scale", Vector3(1.16, 0.86, 1.16), 0.10)
	feedback.tween_property(actor, "scale", Vector3.ONE, 0.13)
	var popup_tween := popup.create_tween()
	popup_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(popup, "scale", Vector2.ONE, 0.11)
	popup_tween.parallel().tween_property(popup, "position:y", popup.position.y - 34.0, 0.34)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.20)
	popup_tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.free()
	, CONNECT_ONE_SHOT)
	return popup_tween


func _play_actor_callout_feedback(actor_node_name: String, text: String) -> Tween:
	var actor := battle_actor_root.get_node_or_null(actor_node_name) as Node3D
	if actor == null or text.is_empty() or battle_feedback_root == null:
		return
	var popup := Label.new()
	popup.name = "ActionCallout"
	popup.text = text
	popup.size = Vector2(190, 62)
	popup.position = _battle_feedback_screen_position(actor.global_position + Vector3.UP * 2.30) - popup.size * 0.5
	popup.pivot_offset = popup.size * 0.5
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_override("font", APP_FONT)
	popup.add_theme_font_size_override("font_size", 30)
	popup.add_theme_color_override("font_color", Color("ffd166"))
	popup.add_theme_color_override("font_outline_color", Color("3b2026"))
	popup.add_theme_constant_override("outline_size", 7)
	popup.z_index = 300
	popup.scale = Vector2(0.30, 0.30)
	battle_feedback_root.add_child(popup)
	var popup_tween := popup.create_tween()
	popup_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	popup_tween.tween_property(popup, "scale", Vector2.ONE, 0.11)
	popup_tween.parallel().tween_property(popup, "position:y", popup.position.y - 40.0, 0.34)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.20)
	popup_tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.free()
	, CONNECT_ONE_SHOT)
	return popup_tween


func _on_presenter_state_changed(_state: String) -> void:
	if hud != null:
		hud.queue_redraw()


func _add_battle_stage_decor() -> void:
	if presentation.is_empty() or combat == null:
		return
	var decor: Dictionary = presentation.get("decor", {})
	var boundary_edges := _battle_footprint_boundary_edges()
	if boundary_edges.is_empty():
		return
	var entrance := _battle_room_entrance_edge(boundary_edges)
	var viewer_direction := Vector2(sin(battle_camera_yaw), cos(battle_camera_yaw)).normalized()
	var far_edge: Dictionary = boundary_edges[0]
	var far_score := INF
	var active_center := Vector3.ZERO
	var active_count := 0
	for y in range(combat.rows):
		for x in range(combat.cols):
			var cell := Vector2i(x, y)
			if _battle_cell_in_room_footprint(cell):
				active_center += _battle_world(cell)
				active_count += 1
	for edge: Dictionary in boundary_edges:
		if str(edge.get("key", "")) == str(entrance.get("key", "")):
			continue
		var direction: Vector2i = edge["direction"]
		var score := Vector2(float(direction.x), float(direction.y)).dot(viewer_direction)
		if score < far_score:
			far_score = score
			far_edge = edge
	active_center /= maxf(1.0, float(active_count))
	var entrance_position := _battle_shell_edge_center(entrance)
	var far_position := _battle_shell_edge_center(far_edge)
	var entrance_direction: Vector2i = entrance["direction"]
	var far_direction: Vector2i = far_edge["direction"]
	entrance_position -= Vector3(float(entrance_direction.x), 0.0, float(entrance_direction.y)) * 0.08
	far_position -= Vector3(float(far_direction.x), 0.0, float(far_direction.y)) * 0.08
	# The Web door belongs to the formal room presentation. The combat test
	# arena intentionally stays open and must not grow a decorative door.
	if not host.test_combat_active and not host.combat_presentation_lab:
		# Align it to the entrance wall; the old billboard always faced the
		# camera and produced the broken door orientation/black bar.
		_add_decor_sprite("StageDoor", str(decor.get("door", "")), entrance_position + Vector3.UP * 0.92, 0.0036, false, _battle_shell_direction_yaw(entrance_direction))
	_add_decor_sprite("StageWindow", str(decor.get("window", "")), far_position + Vector3.UP * 1.05, 0.0035)
	var lamp_position := active_center + Vector3.UP * 2.55
	_add_box(battle_board_root, "OverheadRigCable", active_center + Vector3.UP * 3.22, Vector3(0.028, 1.34, 0.028), _material(Color("39555b")))
	_add_decor_sprite("StageLamp", str(decor.get("pendant_lamp", "")), lamp_position, 0.0044)
	_add_decor_sprite("StageAnchor", str(decor.get("signal_anchor", "")), far_position + Vector3.UP * 0.48, 0.0035)


func _battle_shell_edge_center(edge: Dictionary) -> Vector3:
	var cell: Vector2i = edge.get("cell", Vector2i.ZERO)
	var direction: Vector2i = edge.get("direction", Vector2i.UP)
	return _battle_world(cell) + Vector3(float(direction.x) * BATTLE_CELL * 0.5, 0.0, float(direction.y) * BATTLE_CELL * 0.5)


func _add_battle_room_shell() -> void:
	battle_shell_edge_records.clear()
	battle_shell_culled_count = 0
	battle_shell_visible_count = 0
	var shell := Node3D.new()
	shell.name = "BattleRoomShell"
	battle_board_root.add_child(shell)
	var boundary_edges := _battle_footprint_boundary_edges()
	var entrance: Dictionary = _battle_room_entrance_edge(boundary_edges)
	for edge_index in range(boundary_edges.size()):
		var edge := boundary_edges[edge_index] as Dictionary
		_add_battle_shell_edge(shell, edge, edge_index, str(edge.get("key", "")) == str(entrance.get("key", "")))
	_add_battle_shell_junctions(shell, boundary_edges)
	_add_battle_boundary_outline(shell, boundary_edges)
	_apply_battle_room_cutaway()


func _battle_footprint_boundary_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for y in range(combat.rows):
		for x in range(combat.cols):
			var cell := Vector2i(x, y)
			if not _battle_cell_in_room_footprint(cell):
				continue
			for side in range(RoomRules.DIRS.size()):
				var direction: Vector2i = RoomRules.DIRS[side]
				var neighbor := cell + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < combat.cols and neighbor.y < combat.rows and _battle_cell_in_room_footprint(neighbor):
					continue
				result.append({
					"key": "%d,%d:%d" % [cell.x, cell.y, side],
					"cell": cell,
					"side": side,
					"direction": direction,
				})
	return result


func _battle_room_entrance_edge(boundary_edges: Array[Dictionary]) -> Dictionary:
	if boundary_edges.is_empty():
		return {}
	var preferred_side := battle_entry_side
	var preferred_cell := battle_entry_cell
	var candidates: Array[Dictionary] = []
	for edge: Dictionary in boundary_edges:
		if preferred_side >= 0 and int(edge.get("side", -1)) != preferred_side:
			continue
		candidates.append(edge)
	if candidates.is_empty():
		# 入口信息缺失时采用稳定的房间边界顺序，不能退化为按角色距离猜门。
		candidates = boundary_edges.duplicate(true)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var side_a := int(a.get("side", 0))
			var side_b := int(b.get("side", 0))
			if side_a != side_b:
				return side_a < side_b
			var cell_a: Vector2i = a.get("cell", Vector2i.ZERO)
			var cell_b: Vector2i = b.get("cell", Vector2i.ZERO)
			return cell_a.y < cell_b.y or (cell_a.y == cell_b.y and cell_a.x < cell_b.x)
		)
	var best: Dictionary = candidates[0]
	for edge: Dictionary in candidates:
		if edge.get("cell", Vector2i(-999, -999)) == preferred_cell:
			best = edge
			break
	best = best.duplicate(true)
	best["source"] = "house_entry" if preferred_side >= 0 else "room_definition"
	return best


func _add_battle_shell_edge(shell: Node3D, edge: Dictionary, edge_index: int, is_entrance: bool) -> void:
	var side := int(edge["side"])
	var cell: Vector2i = edge["cell"]
	var segment := Node3D.new()
	segment.name = "ShellEdge_%d_%d_%d" % [cell.x, cell.y, side]
	segment.set_meta("side", side)
	segment.set_meta("cell", cell)
	segment.set_meta("is_entrance", is_entrance)
	var direction: Vector2i = RoomRules.DIRS[side]
	segment.position = _battle_world(cell) + Vector3(float(direction.x) * BATTLE_CELL * 0.5, 0.34, float(direction.y) * BATTLE_CELL * 0.5)
	segment.rotation.y = _battle_shell_direction_yaw(direction)
	shell.add_child(segment)
	var full_root := Node3D.new()
	full_root.name = "FullDoorway" if is_entrance else "FullWall"
	segment.add_child(full_root)
	var shell_color := int(battle_room_context.get("shell_color", 0))
	var wall_kind := _battle_shell_kind_for_segment(edge_index)
	var model := CardboardShellBuilder.build_doorway(Vector3.ZERO, 0.0, shell_color) if is_entrance else CardboardShellBuilder.build_wall(wall_kind, Vector3.ZERO, 0.0, shell_color)
	if model != null:
		model.name = "ShellAsset"
		var source_height := CardboardShellBuilder.WALL_HEIGHT if is_entrance else CardboardShellBuilder.wall_height_for_kind(wall_kind)
		model.scale = Vector3(
			(BATTLE_CELL - BATTLE_SHELL_JUNCTION_WIDTH) / CardboardShellBuilder.WALL_SPAN,
			BATTLE_SHELL_WALL_HEIGHT / maxf(source_height, 0.01),
			1.0
		)
		if is_entrance:
			var door_leaf := model.get_node_or_null("DoorLeaf") as Node3D
			if door_leaf != null:
				door_leaf.visible = false
		for raw_foot: Node in model.find_children("BackFoot_*", "MeshInstance3D", true, false):
			(raw_foot as MeshInstance3D).visible = false
		full_root.add_child(model)
	var cutaway_root := Node3D.new()
	cutaway_root.name = "DoorThreshold" if is_entrance else "WallSill"
	cutaway_root.visible = false
	segment.add_child(cutaway_root)
	_add_battle_shell_sill(cutaway_root, is_entrance)
	var key := str(edge["key"])
	battle_shell_edge_records[key] = {"side": side, "cell": cell, "full": full_root, "cutaway": cutaway_root, "entrance": is_entrance}


func _battle_shell_kind_for_segment(index: int) -> String:
	var wall_kinds: Array = battle_room_context.get("wall_kinds", [])
	if "cb_shelves" in wall_kinds and index % 3 == 1:
		return "cb_shelves"
	if "cb_wall_half" in wall_kinds and index % 4 == 2:
		return "cb_wall_half"
	return "cb_wall"


func _add_battle_shell_junctions(shell: Node3D, boundary_edges: Array[Dictionary]) -> void:
	var shell_color := int(battle_room_context.get("shell_color", 0))
	var horizontal_scale := BATTLE_SHELL_JUNCTION_WIDTH / CardboardShellBuilder.KAYKIT_JUNCTION_WIDTH
	var endpoint_records: Dictionary = {}
	for edge: Dictionary in boundary_edges:
		var cell: Vector2i = edge["cell"]
		var direction: Vector2i = edge["direction"]
		var center := _battle_world(cell) + Vector3(float(direction.x) * BATTLE_CELL * 0.5, 0.34, float(direction.y) * BATTLE_CELL * 0.5)
		var tangent := Vector3.RIGHT if direction.y != 0 else Vector3.BACK
		var tangent_axis := "x" if direction.y != 0 else "z"
		for sign_value in [-1.0, 1.0]:
			var endpoint := center + tangent * BATTLE_CELL * 0.5 * float(sign_value)
			var key := "%0.3f,%0.3f" % [endpoint.x, endpoint.z]
			var record: Dictionary = endpoint_records.get(key, {"position": endpoint, "axes": []})
			(record["axes"] as Array).append(tangent_axis)
			endpoint_records[key] = record
	var keys: Array = endpoint_records.keys()
	keys.sort()
	for raw_key: Variant in keys:
		var record: Dictionary = endpoint_records[raw_key]
		var axes: Array = record["axes"]
		# Neighbouring boundary cells share a collinear seam. A post at every one
		# of those seams reads as a picket fence and scatters support feet across
		# the playable floor, so only actual contour turns/endpoints receive a
		# cardboard junction.
		if axes.size() == 2 and axes[0] == axes[1]:
			continue
		var corner: Vector3 = record["position"]
		var junction := CardboardShellBuilder.build_junction(Vector3.ZERO, CardboardShellBuilder.WALL_HEIGHT, shell_color)
		junction.name = "BattleShellJunction"
		junction.position = corner
		junction.scale = Vector3(horizontal_scale, BATTLE_SHELL_WALL_HEIGHT / CardboardShellBuilder.WALL_HEIGHT, horizontal_scale)
		shell.add_child(junction)


func _add_battle_shell_sill(parent: Node3D, is_entrance: bool) -> void:
	var span := BATTLE_CELL - BATTLE_SHELL_JUNCTION_WIDTH
	if not is_entrance:
		_add_box(parent, "CutawayWallBase", Vector3(0, 0.07, 0), Vector3(span, 0.14, 0.16), _material(Color("54757a")))
		return
	var opening := minf(0.88, span * 0.46)
	var side_span := (span - opening) * 0.5
	var offset := opening * 0.5 + side_span * 0.5
	_add_box(parent, "DoorBaseLeft", Vector3(-offset, 0.07, 0), Vector3(side_span, 0.14, 0.16), _material(Color("54757a")))
	_add_box(parent, "DoorBaseRight", Vector3(offset, 0.07, 0), Vector3(side_span, 0.14, 0.16), _material(Color("54757a")))
	_add_box(parent, "EntranceThreshold", Vector3(0, 0.025, 0), Vector3(opening, 0.04, 0.24), _material(COL_GOLD, false, 0.05))


func _battle_shell_direction_yaw(direction: Vector2i) -> float:
	if direction == Vector2i.RIGHT:
		return -PI * 0.5
	if direction == Vector2i.LEFT:
		return PI * 0.5
	if direction == Vector2i.DOWN:
		return PI
	return 0.0


func _add_battle_boundary_outline(shell: Node3D, boundary_edges: Array[Dictionary]) -> void:
	for edge_index in range(boundary_edges.size()):
		var edge := boundary_edges[edge_index] as Dictionary
		var cell: Vector2i = edge["cell"]
		var direction: Vector2i = edge["direction"]
		var position := _battle_world(cell) + Vector3(float(direction.x) * (BATTLE_CELL * 0.5 - 0.08), 0.39, float(direction.y) * (BATTLE_CELL * 0.5 - 0.08))
		var size := Vector3(BATTLE_CELL - 0.16, 0.045, 0.08) if direction.y != 0 else Vector3(0.08, 0.045, BATTLE_CELL - 0.16)
		_add_box(shell, "BattleBoundary_%03d" % edge_index, position, size, _material(COL_GOLD, false, 0.04))


func _apply_battle_room_cutaway() -> void:
	if combat == null or battle_shell_edge_records.is_empty():
		return
	battle_shell_culled_count = 0
	battle_shell_visible_count = 0
	var viewer_direction := Vector2(sin(battle_camera_yaw), cos(battle_camera_yaw)).normalized()
	for raw_record: Variant in battle_shell_edge_records.values():
		var record: Dictionary = raw_record
		var side := int(record["side"])
		var direction: Vector2i = RoomRules.DIRS[side]
		var outward := Vector2(float(direction.x), float(direction.y))
		var full := record["full"] as Node3D
		var cutaway := record["cutaway"] as Node3D
		var was_culled := cutaway.visible and not full.visible
		var threshold := 0.28 if was_culled else 0.42
		var culled := outward.dot(viewer_direction) > threshold
		full.visible = not culled
		cutaway.visible = culled
		if culled:
			battle_shell_culled_count += 1
		else:
			battle_shell_visible_count += 1


func battle_room_shell_debug_state() -> Dictionary:
	var entrance_count := 0
	var entrance_key := ""
	for raw_record: Variant in battle_shell_edge_records.values():
		var record := raw_record as Dictionary
		if bool(record.get("entrance", false)):
			entrance_count += 1
			entrance_key = str(record.get("cell", Vector2i(-999, -999))) + ":" + str(record.get("side", -1))
	return {
		"edges": battle_shell_edge_records.size(),
		"culled": battle_shell_culled_count,
		"visible": battle_shell_visible_count,
		"entrances": entrance_count,
		"entrance_key": entrance_key,
		"entry_side": battle_entry_side,
		"logical_walls": combat.walls.size() if combat != null else 0,
		"room_type": str(battle_room_context.get("room_type", "")),
		"theme": str(battle_room_context.get("theme", "")),
		"context_source": str(battle_room_context.get("source", "")),
		"context_props": (battle_room_context.get("props", []) as Array).size(),
	}


func battle_room_shell_is_consistent() -> bool:
	if combat == null or battle_shell_edge_records.size() != _battle_footprint_boundary_edges().size():
		return false
	var entrance_count := 0
	for raw_record: Variant in battle_shell_edge_records.values():
		var record: Dictionary = raw_record
		var full := record.get("full") as Node3D
		var cutaway := record.get("cutaway") as Node3D
		if full == null or cutaway == null or full.visible == cutaway.visible:
			return false
		if bool(record.get("entrance", false)):
			entrance_count += 1
	return entrance_count == 1 and battle_shell_culled_count > 0 and battle_shell_visible_count > 0
