class_name ChannelBattleWorldRenderer
extends RefCounted

## Runtime renderer for the tactical battle board.
## CombatRules remains authoritative; this module only materializes its state.

const RoomRules = preload("res://scripts/room_rules.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")
const CardboardShellBuilder = preload("res://scripts/cardboard_shell_builder.gd")
const APP_FONT: Font = preload("res://assets/fonts/SourceHanSansCN-Regular.otf")

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
const COL_BLUE := Color("4c92bd")
const COL_GRID_DARK := Color("26343b")
const COL_FLOOR_H0 := Color("70777b")
const COL_WALL_GREEN := Color("3d6e53")
const INVALID_CELL := Vector2i(-999, -999)

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

func _init(next_host) -> void:
	host = next_host


func _clear_children(parent: Node) -> void:
	host._clear_children(parent)


func _battle_world(pos: Vector2i) -> Vector3:
	return host._battle_world(pos)


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_box(parent, node_name, local_position, box_size, material)


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_cylinder(parent, node_name, local_position, radius, height, material)


func _add_label(parent: Node3D, node_name: String, text_value: String, local_position: Vector3, color: Color, font_size: int) -> Label3D:
	return host._add_label(parent, node_name, text_value, local_position, color, font_size)


func _material(color: Color, transparent: bool = false, emission_strength: float = 0.0) -> StandardMaterial3D:
	return host._material(color, transparent, emission_strength)


func _add_decor_sprite(node_name: String, texture_path: String, local_position: Vector3, pixel_size: float) -> void:
	host._add_decor_sprite(node_name, texture_path, local_position, pixel_size)


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


func build_battle_world() -> void:
	_ensure_battle_layers()
	_clear_children(battle_board_root)
	_clear_children(battle_actor_root)
	enemy_nodes.clear()
	_build_battle_board()
	_sync_battle_actors()


func refresh_battle_board() -> void:
	if combat == null:
		return
	_ensure_battle_layers()
	_clear_children(battle_board_root)
	_build_battle_board()


func _build_battle_board() -> void:
	if combat == null:
		return
	var intent: Dictionary = combat.preview_intent()
	var intent_cells: Dictionary = {}
	for enemy_id in combat.living_enemy_ids():
		var enemy_intent: Dictionary = combat.preview_intent(enemy_id)
		for raw_cell in enemy_intent.get("hurt", []):
			intent_cells[raw_cell] = {"kind": "hurt", "enemy_id": enemy_id, "intent": enemy_intent}
		for raw_cell in enemy_intent.get("path", []):
			if not intent_cells.has(raw_cell):
				intent_cells[raw_cell] = {"kind": "path", "enemy_id": enemy_id, "intent": enemy_intent}
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
			var cell_intent: Dictionary = intent_cells.get(pos, {})
			var cell_intent_data: Dictionary = cell_intent.get("intent", intent)
			if cell_intent.get("kind", "") == "hurt" or pos in intent.get("hurt", []):
				rim_color = COL_RED
			elif cell_intent.get("kind", "") == "path" or pos in intent.get("path", []):
				rim_color = COL_BLUE
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
			_add_battle_floor_model(cell_node, pos, footprint_active)
			# Surface remains only as a picking/standing plane. The visible finish is
			# the same KayKit timber module used by the formal big-map composer.
			var surface_alpha := 0.025 if height == 0 else 0.018
			var surface_material := _material(Color(surface_color, surface_alpha), true, 0.018)
			_add_box(cell_node, "Surface", Vector3(0, platform_height + 0.055, 0), Vector3(BATTLE_CELL - 0.34, 0.11, BATTLE_CELL - 0.34), surface_material)
			var top_y := platform_height + 0.13
			var is_hurt_cell: bool = cell_intent.get("kind", "") == "hurt" or pos in (intent.get("hurt", []) as Array)
			var path_cells: Array = cell_intent_data.get("path", intent.get("path", []))
			var path_index: int = path_cells.find(pos)
			if is_hurt_cell:
				# Keep danger readable without painting a large debug-like label across
				# the inherited timber floor. A compact token plus red corners reads as
				# a tabletop warning marker.
				_add_cylinder(cell_node, "IntentAttackOverlay", Vector3(0, top_y + 0.035, 0), 0.34, 0.055, _material(Color(COL_RED, 0.86), true, 0.10))
				_add_corner_marks(cell_node, "IntentAttackCorner", COL_RED, top_y + 0.015)
				var attack_glyph := "!"
				if int(intent.get("hits", 1)) > 1:
					attack_glyph = "×%d" % int(intent.get("hits", 1))
				_add_label(cell_node, "IntentAttackGlyph", attack_glyph, Vector3(0.0, top_y + 0.30, 0.0), Color.WHITE, 25)
			elif path_index >= 0:
				_add_cylinder(cell_node, "IntentMoveOverlay", Vector3(0, top_y + 0.025, 0), 0.25, 0.045, _material(Color(COL_BLUE, 0.82), true, 0.08))
				_add_label(cell_node, "IntentMoveGlyph", str(path_index + 1), Vector3(0.0, top_y + 0.25, 0.0), Color.WHITE, 22)
			# Placement cards need a visible target field. Ordinary movement uses a
			# hover-only marker so idle combat frames stay visually clean.
			if _is_valid_battle_target(pos) and (selected_card >= 0 or pos == hovered_battle_cell):
				_add_corner_marks(cell_node, "Valid", COL_GOLD if selected_card >= 0 else COL_GREEN, top_y)
			if pos == hovered_battle_cell:
				_add_corner_marks(cell_node, "Hover", Color.WHITE, top_y + 0.055)
			if combat.portals.has(pos):
				_add_portal_marker(cell_node, pos, top_y)
			if combat.walls.has(pos) and not backstage:
				var blocker_volume := _add_box(cell_node, "Blocker", Vector3(0, platform_height + 0.70, 0), Vector3(BATTLE_CELL - 0.48, 1.20, BATTLE_CELL - 0.48), _material(Color(room_blocker, 0.03), true, 0.0))
				blocker_volume.visible = false
				_add_battle_blocker_asset(cell_node, pos, platform_height)
			elif combat.traps.has(pos):
				var trap: Dictionary = combat.traps[pos]
				_add_cylinder(cell_node, "Trap", Vector3(0, top_y + 0.08, 0), 0.30, 0.13, _material(COL_GOLD, false, 0.05))
				var card_id := str(trap.get("card_id", ""))
				_add_trap_item_sprite(cell_node, card_id, top_y)
				_add_label(cell_node, "TrapGlyph", str(trap.get("glyph", "✦")), Vector3(0, top_y + 0.62, 0), COL_GOLD, 21)
	_add_battle_room_shell()
	_add_battle_stage_decor()


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


func _is_valid_battle_target(pos: Vector2i) -> bool:
	if combat == null or combat.outcome != "":
		return false
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
			if candidate == combat.player_pos or candidate == combat.enemy_pos:
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
	var base_color := COL_TEAL if is_player else COL_RED if revealed else Color("1f2930")
	_add_cylinder(node, "PawnBase", Vector3(0, floor_y + 0.026, 0), 0.46, 0.052, _material(Color(base_color, 0.58), true, 0.035))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0, floor_y + 0.05, 0)
	node.add_child(presenter)
	var actor_key := "player" if is_player else "enemy"
	var enemy_state = combat.enemy_by_id(enemy_id) if not is_player else null
	var presenter_id := actor_key if is_player else "%s:%s" % [actor_key, str(enemy_state.archetype if enemy_state != null else combat.enemy_archetype)]
	presenter.configure(presenter_id, _battle_actor_presentation(actor_key, enemy_id))
	presenter.state_changed.connect(_on_presenter_state_changed)
	if not is_player:
		presenter.set_obscured(not revealed)
	if not is_player:
		if revealed and combat != null and str(combat.outcome) == "":
			var intent: Dictionary = combat.preview_intent(enemy_id)
			var intent_color := _battle_intent_color(str(intent.get("type", "stall")))
			var intent_badge := MeshInstance3D.new()
			intent_badge.name = "EnemyIntentBadge"
			var intent_quad := QuadMesh.new()
			intent_quad.size = Vector2(0.72, 0.72)
			intent_badge.mesh = intent_quad
			intent_badge.position = Vector3(0, floor_y + 2.44, 0)
			var badge_material := _material(Color(intent_color, 0.88), true, 0.08)
			badge_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			badge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			intent_badge.material_override = badge_material
			node.add_child(intent_badge)
			var intent_label := Label3D.new()
			intent_label.font = APP_FONT
			intent_label.name = "EnemyIntent"
			intent_label.position = Vector3(0, floor_y + 2.44, 0.02)
			intent_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			intent_label.no_depth_test = true
			intent_label.font_size = 38
			intent_label.pixel_size = 0.010
			intent_label.outline_size = 7
			intent_label.outline_modulate = Color("10151c")
			intent_label.modulate = Color.WHITE
			intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			intent_label.text = _battle_intent_glyph(str(intent.get("type", "stall")))
			node.add_child(intent_label)


func _battle_intent_color(intent_type: String) -> Color:
	match intent_type:
		"attack": return Color("ff5a4e")
		"chase": return Color("ff9c4a")
		"search": return Color("6ab7e8")
		"patrol": return Color("5fd6c6")
		"ambush": return Color("e06bb4")
	return Color("c8d4d8")


func _battle_intent_glyph(intent_type: String) -> String:
	match intent_type:
		"attack": return "攻"
		"chase": return "追"
		"search": return "搜"
		"patrol": return "巡"
		"ambush": return "伏"
	return "待"


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
	var actor := battle_actor_root.get_node_or_null(actor_node_name) as Node3D
	if actor == null or damage <= 0:
		return
	var popup := Label3D.new()
	popup.font = APP_FONT
	popup.name = "DamageFeedback"
	popup.text = "✦  -%d  ✦" % damage
	popup.position = Vector3(0, 1.28, 0.12)
	popup.font_size = 58
	popup.pixel_size = 0.014
	popup.modulate = Color("ff4e61")
	popup.outline_modulate = Color("fff2d2")
	popup.outline_size = 12
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	popup.scale = Vector3(0.35, 0.35, 0.35)
	actor.add_child(popup)
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
	popup_tween.tween_property(popup, "scale", Vector3.ONE, 0.11)
	popup_tween.parallel().tween_property(popup, "position:y", 1.72, 0.34)
	popup_tween.tween_property(popup, "modulate:a", 0.0, 0.20)
	popup_tween.tween_callback(popup.queue_free)


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
	_add_decor_sprite("StageDoor", str(decor.get("door", "")), entrance_position + Vector3.UP * 0.92, 0.0036)
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
	var player: Vector2i = combat.player_pos
	var entered_from: Vector2i = previous_room_pos - current_room_pos
	var linked_side := RoomRules.DIRS.find(entered_from)
	var prefer_house_side: bool = linked_side >= 0 and room_rules.placed.has(current_room_pos) and room_rules.cell_has_door(current_room_pos, linked_side)
	var best: Dictionary = boundary_edges[0]
	var best_score := INF
	for edge: Dictionary in boundary_edges:
		var cell: Vector2i = edge["cell"]
		var side := int(edge["side"])
		var side_penalty := 0.0 if not prefer_house_side or side == linked_side else 100.0
		var score := side_penalty + float(absi(cell.x - player.x) + absi(cell.y - player.y))
		if score < best_score:
			best = edge
			best_score = score
	best = best.duplicate(true)
	best["source"] = "house_entry" if prefer_house_side else "player_spawn"
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
	for raw_record: Variant in battle_shell_edge_records.values():
		if bool((raw_record as Dictionary).get("entrance", false)):
			entrance_count += 1
	return {
		"edges": battle_shell_edge_records.size(),
		"culled": battle_shell_culled_count,
		"visible": battle_shell_visible_count,
		"entrances": entrance_count,
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
