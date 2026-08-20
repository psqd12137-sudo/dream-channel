@tool
extends Node3D

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")
const RoomPropCatalog = preload("res://scripts/room_prop_catalog.gd")

const KENNEY_ROOT := "res://assets/third_party/kenney_mini_dungeon/models/"
const KAYKIT_ROOT := "res://assets/third_party/kaykit_dungeon/models/"
const RUINS_ROOT := "res://assets/third_party/quaternius_ultimate_modular_ruins/models/"
const CELL := 1.55
const ELEVATION_STEP := 0.58
const KAYKIT_WALL_HEIGHT := 1.08
const KAYKIT_JUNCTION_WIDTH := 0.28
const CARDBOARD_PANEL_THICKNESS := 0.10
const CARDBOARD_DOOR_OPENING := 0.66
const KAYKIT_FLOOR_SCALE := Vector3.ONE * (CELL / 4.0)
const KAYKIT_WALL_SCALE := Vector3((CELL - KAYKIT_JUNCTION_WIDTH) / 4.0, KAYKIT_WALL_HEIGHT / 4.0, KAYKIT_JUNCTION_WIDTH)
const KAYKIT_DOOR_SCALE := Vector3((CELL - KAYKIT_JUNCTION_WIDTH) / 4.0, KAYKIT_WALL_HEIGHT / 4.0, KAYKIT_JUNCTION_WIDTH)
const KAYKIT_STAIR_SCALE := Vector3(CELL / 3.3, ELEVATION_STEP / 4.05, CELL / 6.0)
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SHAPE_SEQUENCE := ["single", "plus5", "l3", "single", "line3", "single", "l3", "single", "t5", "single"]

@export var generation_seed := 20260816
@export_range(6, 16, 1) var room_target := 10
@export var show_room_ids := true
@export var animate_room_build := true
@export var kenney_only := true
@export var use_kaykit_room_shell := true
@export var use_toy_show_cardboard_shell := true
@export var use_toy_show_shell_palette := true
@export var unify_room_floor_finish := false
@export var open_visited_connections := false
@export_range(0.08, 0.8, 0.01) var room_drop_duration := 0.24
@export_range(0.0, 0.4, 0.01) var room_drop_gap := 0.06

var occupancy: Dictionary = {}
var rooms: Array[Dictionary] = []
var connection_edges: Dictionary = {}
var explicit_open_edges: Dictionary = {}
var generated_root: Node3D
var room_visual_roots: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var build_tween: Tween = null
var external_wall_count := 0
var divider_wall_count := 0
var doorway_count := 0
var open_passage_count := 0
var stair_count := 0
var prop_count := 0
var prop_placement_records: Array[Dictionary] = []
var prop_placement_issues: Array[String] = []
var wall_bound_prop_nodes: Dictionary = {}
var interaction_slot_records: Array[Dictionary] = []
var interaction_slot_issues: Array[String] = []
var show_evidence_records: Array[Dictionary] = []
var show_evidence_issues: Array[String] = []
var production_fixture_records: Array[Dictionary] = []
var production_fixture_issues: Array[String] = []
var room_broadcast_states: Dictionary = {}
var toy_show_shell_nodes: Array[Node3D] = []
var cardboard_shell_records: Array[Dictionary] = []
var junction_count := 0
var visual_edge_records: Dictionary = {}
var visual_geometry_issues: Array[String] = []
var structural_edge_nodes: Dictionary = {}
var structural_junction_nodes: Array[Node3D] = []
var cutaway_marker_nodes: Dictionary = {}
var cutaway_culled_edge_keys: Array[String] = []
var cutaway_culled_wall_count := 0
var cutaway_culled_doorway_count := 0
var cutaway_visible_wall_count := 0
var cutaway_visible_doorway_count := 0
var cutaway_open_passage_count := 0
var cutaway_focus_room_index := -1
var layout_extent := 8.0
var layout_center := Vector2.ZERO

@onready var standalone_rig: Node3D = $StandaloneRig
@onready var standalone_camera: Camera3D = $StandaloneRig/Camera3D


func _ready() -> void:
	var standalone := Engine.is_editor_hint() or get_parent() == get_tree().root or get_tree().current_scene == self
	standalone_rig.visible = standalone
	regenerate(generation_seed)
	if standalone and not Engine.is_editor_hint():
		standalone_camera.current = true
		_apply_standalone_camera()


func regenerate(seed_value: int) -> void:
	generation_seed = seed_value
	rng.seed = generation_seed
	if build_tween != null and build_tween.is_valid():
		build_tween.kill()
	build_tween = null
	_clear_generated()
	occupancy.clear()
	rooms.clear()
	connection_edges.clear()
	external_wall_count = 0
	divider_wall_count = 0
	doorway_count = 0
	open_passage_count = 0
	stair_count = 0
	prop_count = 0
	prop_placement_records.clear()
	prop_placement_issues.clear()
	wall_bound_prop_nodes.clear()
	interaction_slot_records.clear()
	interaction_slot_issues.clear()
	show_evidence_records.clear()
	show_evidence_issues.clear()
	production_fixture_records.clear()
	production_fixture_issues.clear()
	room_broadcast_states.clear()
	toy_show_shell_nodes.clear()
	cardboard_shell_records.clear()
	junction_count = 0
	visual_edge_records.clear()
	visual_geometry_issues.clear()
	structural_edge_nodes.clear()
	structural_junction_nodes.clear()
	cutaway_marker_nodes.clear()
	cutaway_culled_edge_keys.clear()
	cutaway_culled_wall_count = 0
	cutaway_culled_doorway_count = 0
	cutaway_visible_wall_count = 0
	cutaway_visible_doorway_count = 0
	cutaway_open_passage_count = 0
	cutaway_focus_room_index = -1
	_generate_room_layout()
	_build_joined_diorama()
	if animate_room_build and not Engine.is_editor_hint():
		call_deferred("_play_room_build_animation")
	if standalone_rig != null and standalone_rig.visible and not Engine.is_editor_hint():
		_apply_standalone_camera()


func _clear_generated() -> void:
	if generated_root != null and is_instance_valid(generated_root):
		remove_child(generated_root)
		generated_root.free()
	generated_root = Node3D.new()
	generated_root.name = "GeneratedMap"
	add_child(generated_root)
	room_visual_roots.clear()


func _generate_room_layout() -> void:
	_add_room("single", [Vector2i.ZERO], 0.0, "R00")
	for index in range(1, room_target):
		var shape_id: String = str(SHAPE_SEQUENCE[index % SHAPE_SEQUENCE.size()])
		if index >= SHAPE_SEQUENCE.size():
			shape_id = str(["single", "single", "line3", "l3", "plus5", "t5"][rng.randi_range(0, 5)])
		if not _try_place_room(shape_id, index):
			_try_place_room("single", index)


func _try_place_room(shape_id: String, room_index: int) -> bool:
	var best_candidate: Array[Vector2i] = []
	var best_frontier: Dictionary = {}
	var best_score := -INF
	for _attempt in range(280):
		var frontiers := _frontier_edges()
		if frontiers.is_empty():
			return false
		var frontier: Dictionary = frontiers[rng.randi_range(0, frontiers.size() - 1)]
		var shape := _rotated_shape(shape_id, rng.randi_range(0, 3))
		var anchor: Vector2i = shape[rng.randi_range(0, shape.size() - 1)]
		var origin: Vector2i = (frontier["target"] as Vector2i) - anchor
		var candidate: Array[Vector2i] = []
		var legal := true
		for offset: Vector2i in shape:
			var cell := origin + offset
			if occupancy.has(cell) or absi(cell.x) > 9 or absi(cell.y) > 9:
				legal = false
				break
			candidate.append(cell)
		if not legal:
			continue
		var touch_count := _occupied_touch_count(candidate)
		if touch_count == 0 or touch_count > 6:
			continue
		var score := _placement_score(candidate, touch_count) + rng.randf_range(0.0, 0.015)
		if score > best_score:
			best_score = score
			best_candidate = candidate
			best_frontier = frontier
	if best_candidate.is_empty():
		return false
	var elevation := ELEVATION_STEP if best_candidate.size() == 5 and not _has_elevated_room() else 0.0
	var source_cell: Vector2i = best_frontier["source"]
	var target_cell: Vector2i = best_frontier["target"]
	var source_room_index := int(occupancy[source_cell])
	var new_room_index := rooms.size()
	_add_room(shape_id, best_candidate, elevation, "R%02d" % room_index)
	connection_edges[_edge_key(source_cell, target_cell)] = {
		"source": source_cell,
		"target": target_cell,
		"source_room": source_room_index,
		"target_room": new_room_index,
	}
	return true


func _placement_score(candidate: Array[Vector2i], touch_count: int) -> float:
	var combined: Dictionary = occupancy.duplicate()
	for cell: Vector2i in candidate:
		combined[cell] = true
	var first: Vector2i = combined.keys()[0]
	var minimum := first
	var maximum := first
	for raw_cell: Variant in combined.keys():
		var cell: Vector2i = raw_cell
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var width := maximum.x - minimum.x + 1
	var height := maximum.y - minimum.y + 1
	var area := maxi(1, width * height)
	var compactness := float(combined.size()) / float(area)
	var aspect_penalty := absi(width - height)
	var holes := 0
	for y in range(minimum.y + 1, maximum.y):
		for x in range(minimum.x + 1, maximum.x):
			var cell := Vector2i(x, y)
			if combined.has(cell):
				continue
			var surrounded := true
			for direction: Vector2i in DIRS:
				if not combined.has(cell + direction):
					surrounded = false
					break
			if surrounded:
				holes += 1
	var excessive_contacts := maxi(0, touch_count - 2)
	return compactness * 8.0 - float(width + height) * 0.32 - float(aspect_penalty) * 0.78 - float(holes) * 4.0 - float(excessive_contacts) * 0.55


func _add_room(shape_id: String, cells: Array[Vector2i], elevation: float, room_id: String) -> void:
	var room_index := rooms.size()
	var room := {
		"id": room_id,
		"name": room_id,
		"shape": shape_id,
		"size": cells.size(),
		"cells": cells.duplicate(),
		"elevation": elevation,
		"revealed": true,
		"visited": true,
		"completed": false,
		"is_current": false,
	}
	rooms.append(room)
	for cell: Vector2i in cells:
		occupancy[cell] = room_index


func _frontier_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_cell: Variant in occupancy.keys():
		var source: Vector2i = raw_cell
		for direction: Vector2i in DIRS:
			var target := source + direction
			if not occupancy.has(target):
				result.append({"source": source, "target": target})
	return result


func _rotated_shape(shape_id: String, turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var raw_shape: Array = RoomFootprintCatalog.SHAPES.get(shape_id, RoomFootprintCatalog.SHAPES["single"])
	for raw_cell: Array in raw_shape:
		var cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
		for _turn in range(posmod(turns, 4)):
			cell = Vector2i(-cell.y, cell.x)
		result.append(cell)
	return result


func _occupied_touch_count(cells: Array[Vector2i]) -> int:
	var count := 0
	for cell: Vector2i in cells:
		for direction: Vector2i in DIRS:
			if occupancy.has(cell + direction):
				count += 1
	return count


func _has_elevated_room() -> bool:
	for room: Dictionary in rooms:
		if float(room.get("elevation", 0.0)) > 0.0:
			return true
	return false


func _build_joined_diorama() -> void:
	if occupancy.is_empty():
		return
	var bounds := _cell_bounds()
	var center := Vector2((bounds["min"] as Vector2i) + (bounds["max"] as Vector2i)) * 0.5
	layout_center = center
	var size: Vector2i = (bounds["max"] as Vector2i) - (bounds["min"] as Vector2i) + Vector2i.ONE
	layout_extent = maxf(float(size.x), float(size.y)) * CELL
	_prepare_room_visual_roots(center)
	for raw_cell: Variant in occupancy.keys():
		var cell: Vector2i = raw_cell
		_build_cell(cell, center)
	_build_edges(center)
	_build_room_props(center)
	_build_room_state_overlays(center)
	_build_title(size)


func _prepare_room_visual_roots(center: Vector2) -> void:
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var cells: Array[Vector2i] = room["cells"]
		var pivot := Vector3.ZERO
		for cell: Vector2i in cells:
			pivot += _cell_world(cell, center)
		pivot /= maxf(1.0, float(cells.size()))
		var room_root := Node3D.new()
		room_root.name = "RoomVisual_%s" % str(room.get("id", "R%02d" % room_index))
		room_root.position = pivot
		room_root.set_meta("room_index", room_index)
		room_root.set_meta("room_size", int(room.get("size", 1)))
		room_root.set_meta("room_id", str(room.get("id", "R%02d" % room_index)))
		room_root.set_meta("revealed", bool(room.get("revealed", true)))
		room_root.set_meta("visited", bool(room.get("visited", true)))
		room_root.set_meta("completed", bool(room.get("completed", false)))
		room_root.set_meta("is_current", bool(room.get("is_current", false)))
		generated_root.add_child(room_root)
		room_visual_roots.append(room_root)


func _build_cell(cell: Vector2i, center: Vector2) -> void:
	var room_index := int(occupancy[cell])
	var room: Dictionary = rooms[room_index]
	var elevation := float(room.get("elevation", 0.0))
	var world := _cell_world(cell, center)
	var room_color := _room_base_color(room_index, elevation)
	_add_box("Base_%d_%d" % [cell.x, cell.y], world + Vector3(0, (elevation - 0.42) * 0.5, 0), Vector3(CELL, elevation + 0.42, CELL), room_color, room_index)
	var floor_variant_key := str(room.get("id", room_index)).hash() + generation_seed if unify_room_floor_finish else cell.x * 17 + cell.y * 31 + generation_seed
	var floor_asset := KAYKIT_ROOT + ("floor_wood_large_dark.gltf.glb" if use_kaykit_room_shell and posmod(floor_variant_key, 7) == 0 else "floor_wood_large.gltf.glb") if use_kaykit_room_shell else KENNEY_ROOT + ("floor-detail.fbx" if posmod(floor_variant_key, 7) == 0 else "floor.fbx")
	var floor_scale := KAYKIT_FLOOR_SCALE if use_kaykit_room_shell else Vector3.ONE * CELL
	_add_model("Floor_%d_%d" % [cell.x, cell.y], floor_asset, world + Vector3(0, elevation + 0.025, 0), floor_scale, 0.0, room_index)


func _room_base_color(room_index: int, elevation: float) -> Color:
	var palette := [Color("303840"), Color("38433e"), Color("3e3945"), Color("3f4035")]
	var color: Color = palette[posmod(room_index, palette.size())]
	return color.lightened(0.12) if elevation > 0.0 else color


func _build_edges(center: Vector2) -> void:
	var junctions: Dictionary = {}
	for raw_cell: Variant in occupancy.keys():
		var cell: Vector2i = raw_cell
		var room_index := int(occupancy[cell])
		var elevation := float(rooms[room_index].get("elevation", 0.0))
		for side in range(4):
			var neighbor: Vector2i = cell + DIRS[side]
			if occupancy.has(neighbor):
				if _cell_precedes(neighbor, cell):
					continue
				var other_index := int(occupancy[neighbor])
				if other_index == room_index:
					continue
				var edge_key := _edge_key(cell, neighbor)
				if connection_edges.has(edge_key):
					var passage_open := _connection_is_open(cell, neighbor)
					_spawn_connection(cell, neighbor, side, center, passage_open)
					_record_visual_edge(edge_key, "door", cell, neighbor, passage_open)
					_register_edge_junctions(cell, side, center, minf(elevation, float(rooms[other_index].get("elevation", 0.0))), room_index, junctions)
				else:
					_spawn_wall(cell, side, center, elevation, true)
					divider_wall_count += 1
					_record_visual_edge(edge_key, "divider", cell, neighbor)
					_register_edge_junctions(cell, side, center, elevation, room_index, junctions)
				continue
			if explicit_open_edges.is_empty() and side == 2:
				continue
			var boundary_key := _edge_key(cell, neighbor)
			if not explicit_open_edges.is_empty() and explicit_open_edges.has(boundary_key):
				_spawn_outer_doorway(cell, side, center, elevation)
				_record_visual_edge(boundary_key, "door", cell, neighbor)
				_register_edge_junctions(cell, side, center, elevation, room_index, junctions)
			else:
				_spawn_wall(cell, side, center, elevation, false)
				external_wall_count += 1
				_record_visual_edge(boundary_key, "outer", cell, neighbor)
				_register_edge_junctions(cell, side, center, elevation, room_index, junctions)
	_spawn_edge_junctions(junctions)


func _spawn_wall(cell: Vector2i, side: int, center: Vector2, elevation: float, divider: bool) -> void:
	var direction: Vector2i = DIRS[side]
	var neighbor := cell + direction
	var edge_key := _edge_key(cell, neighbor)
	var edge_kind := "divider" if divider else "outer"
	var base := _cell_world(cell, center)
	if use_toy_show_cardboard_shell:
		var wall_position := base + Vector3(float(direction.x) * CELL * 0.5, elevation + 0.025, float(direction.y) * CELL * 0.5)
		var cardboard_wall := _add_cardboard_wall(
			"%sWall_%d_%d_%d" % ["Divider" if divider else "Outer", cell.x, cell.y, side],
			wall_position, _direction_yaw(direction), int(occupancy[cell]), edge_key, edge_kind
		)
		_tag_structural_edge(cardboard_wall, edge_key, edge_kind, cell, neighbor, direction)
		return
	if use_kaykit_room_shell:
		var wall_position := base + Vector3(float(direction.x) * CELL * 0.5, elevation + 0.025, float(direction.y) * CELL * 0.5)
		var kaykit_wall := _add_model("%sWall_%d_%d_%d" % ["Divider" if divider else "Outer", cell.x, cell.y, side], KAYKIT_ROOT + "wall.gltf.glb", wall_position, KAYKIT_WALL_SCALE, _direction_yaw(direction), int(occupancy[cell]))
		_tag_structural_edge(kaykit_wall, edge_key, edge_kind, cell, neighbor, direction)
		return
	if kenney_only:
		var kenney_asset := KENNEY_ROOT + ("wall-half.fbx" if not divider and posmod(cell.x * 11 + cell.y * 23 + side + generation_seed, 5) == 0 else "wall.fbx")
		var kenney_wall := _add_model("%sWall_%d_%d_%d" % ["Divider" if divider else "Outer", cell.x, cell.y, side], kenney_asset, base + Vector3(0, elevation + 0.025, 0), Vector3.ONE * CELL, _direction_yaw(direction), int(occupancy[cell]))
		_tag_structural_edge(kenney_wall, edge_key, edge_kind, cell, neighbor, direction)
		return
	var position := base + Vector3(float(direction.x) * CELL * 0.5, elevation + 0.02, float(direction.y) * CELL * 0.5)
	var asset := RUINS_ROOT + ("Wall_Broken.fbx" if not divider and posmod(cell.x * 11 + cell.y * 23 + side + generation_seed, 5) == 0 else "Wall.fbx")
	var scale_value := Vector3(CELL * 0.5, 0.55 if not divider else 0.47, 0.72)
	var ruins_wall := _add_model("%sWall_%d_%d_%d" % ["Divider" if divider else "Outer", cell.x, cell.y, side], asset, position, scale_value, PI * 0.5 if side in [1, 3] else 0.0, int(occupancy[cell]))
	_tag_structural_edge(ruins_wall, edge_key, edge_kind, cell, neighbor, direction)


func _connection_is_open(cell: Vector2i, neighbor: Vector2i) -> bool:
	if not open_visited_connections:
		return false
	var room_a: Dictionary = rooms[int(occupancy[cell])]
	var room_b: Dictionary = rooms[int(occupancy[neighbor])]
	return bool(room_a.get("visited", false)) and bool(room_b.get("visited", false))


func _spawn_connection(cell: Vector2i, neighbor: Vector2i, side: int, center: Vector2, passage_open: bool) -> void:
	var elevation_a := float(rooms[int(occupancy[cell])].get("elevation", 0.0))
	var elevation_b := float(rooms[int(occupancy[neighbor])].get("elevation", 0.0))
	var low_elevation := minf(elevation_a, elevation_b)
	var direction: Vector2i = DIRS[side]
	var position := _cell_world(cell, center) + Vector3(float(direction.x) * CELL * 0.5, low_elevation + 0.02, float(direction.y) * CELL * 0.5)
	var yaw := PI * 0.5 if side in [1, 3] else 0.0
	var connection_room_index := maxi(int(occupancy[cell]), int(occupancy[neighbor]))
	var doorway_model: Node3D = null
	if passage_open:
		doorway_model = Node3D.new()
		doorway_model.name = "OpenPassage_%d" % doorway_count
		doorway_model.rotation.y = _direction_yaw(direction)
		_add_to_visual_root(doorway_model, connection_room_index, position)
		open_passage_count += 1
	elif use_toy_show_cardboard_shell:
		doorway_model = _add_cardboard_doorway("Doorway_%d" % doorway_count, position, _direction_yaw(direction), connection_room_index, _edge_key(cell, neighbor))
	elif use_kaykit_room_shell:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KAYKIT_ROOT + "wall_doorway.glb", position, KAYKIT_DOOR_SCALE, _direction_yaw(direction), connection_room_index)
	elif kenney_only:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KENNEY_ROOT + "wall-opening.fbx", _cell_world(cell, center) + Vector3(0, elevation_a + 0.025, 0), Vector3.ONE * CELL, _direction_yaw(direction), connection_room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * CELL, _direction_yaw(direction), connection_room_index)
	else:
		doorway_model = _add_model("Doorway_%d" % doorway_count, RUINS_ROOT + "Arch_Round.fbx", position, Vector3(CELL / 3.1, 0.38, 0.55), yaw, connection_room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * 1.12, yaw, connection_room_index)
	_tag_structural_edge(doorway_model, _edge_key(cell, neighbor), "door", cell, neighbor, direction, passage_open)
	doorway_count += 1
	if not is_equal_approx(elevation_a, elevation_b):
		var lower_cell := cell if elevation_a < elevation_b else neighbor
		var higher_cell := neighbor if elevation_a < elevation_b else cell
		var climb := higher_cell - lower_cell
		var stair_position := (_cell_world(lower_cell, center) + _cell_world(higher_cell, center)) * 0.5
		stair_position.y = minf(elevation_a, elevation_b) + 0.02
		var stair_yaw := _direction_yaw(climb)
		if use_kaykit_room_shell:
			_add_model("Stairs_%d" % stair_count, KAYKIT_ROOT + "stairs_wood.gltf.glb", stair_position, KAYKIT_STAIR_SCALE, stair_yaw, connection_room_index)
		elif kenney_only:
			_add_model("Stairs_%d" % stair_count, KENNEY_ROOT + "stairs.fbx", _cell_world(lower_cell, center) + Vector3(0, minf(elevation_a, elevation_b) + 0.025, 0), Vector3.ONE * CELL, stair_yaw, connection_room_index)
		else:
			_add_model("Stairs_%d" % stair_count, RUINS_ROOT + "Stairs.fbx", stair_position, Vector3(0.42, 0.5, 0.42), stair_yaw, connection_room_index)
		stair_count += 1


func _spawn_outer_doorway(cell: Vector2i, side: int, center: Vector2, elevation: float) -> void:
	var direction: Vector2i = DIRS[side]
	var neighbor := cell + direction
	var room_index := int(occupancy[cell])
	var position := _cell_world(cell, center) + Vector3(float(direction.x) * CELL * 0.5, elevation + 0.02, float(direction.y) * CELL * 0.5)
	var yaw := PI * 0.5 if side in [1, 3] else 0.0
	var doorway_model: Node3D = null
	if use_toy_show_cardboard_shell:
		doorway_model = _add_cardboard_doorway("Doorway_%d" % doorway_count, position, _direction_yaw(direction), room_index, _edge_key(cell, neighbor))
	elif use_kaykit_room_shell:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KAYKIT_ROOT + "wall_doorway.glb", position, KAYKIT_DOOR_SCALE, _direction_yaw(direction), room_index)
	elif kenney_only:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KENNEY_ROOT + "wall-opening.fbx", _cell_world(cell, center) + Vector3(0, elevation + 0.025, 0), Vector3.ONE * CELL, _direction_yaw(direction), room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * CELL, _direction_yaw(direction), room_index)
	else:
		doorway_model = _add_model("Doorway_%d" % doorway_count, RUINS_ROOT + "Arch_Round.fbx", position, Vector3(CELL / 3.1, 0.38, 0.55), yaw, room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * 1.12, yaw, room_index)
	_tag_structural_edge(doorway_model, _edge_key(cell, neighbor), "door", cell, neighbor, direction)
	doorway_count += 1

func _record_visual_edge(key: String, kind: String, cell: Vector2i, neighbor: Vector2i, passage_open := false) -> void:
	if visual_edge_records.has(key):
		visual_geometry_issues.append("duplicate visual edge %s" % key)
		return
	visual_edge_records[key] = {"kind": kind, "cell": cell, "neighbor": neighbor, "passage_open": passage_open}


func _tag_structural_edge(node: Node3D, edge_key: String, kind: String, cell: Vector2i, neighbor: Vector2i, direction: Vector2i, passage_open := false) -> void:
	if node == null:
		return
	node.set_meta("structure_kind", kind)
	node.set_meta("edge_key", edge_key)
	node.set_meta("edge_cell", cell)
	node.set_meta("edge_neighbor", neighbor)
	node.set_meta("edge_direction", direction)
	node.set_meta("passage_open", passage_open)
	structural_edge_nodes[edge_key] = node
	_create_cutaway_marker(node, edge_key, kind)


func _create_cutaway_marker(structure: Node3D, edge_key: String, kind: String) -> void:
	var marker := Node3D.new()
	marker.name = "CutawayMarker_%s" % edge_key.replace("-", "m").replace(",", "_").replace("|", "__")
	marker.position = structure.position
	marker.rotation.y = structure.rotation.y
	marker.visible = false
	marker.set_meta("edge_key", edge_key)
	marker.set_meta("structure_kind", kind)
	marker.set_meta("passage_open", bool(structure.get_meta("passage_open", false)))
	structure.get_parent().add_child(marker)
	var span := CELL - KAYKIT_JUNCTION_WIDTH
	if kind == "door":
		var opening := 0.66
		var end_span := (span - opening) * 0.5
		var offset := opening * 0.5 + end_span * 0.5
		_add_cutaway_box(marker, "DoorSillLeft", Vector3(-offset, 0.07, 0), Vector3(end_span, 0.12, 0.13), Color("54757a"))
		_add_cutaway_box(marker, "DoorSillRight", Vector3(offset, 0.07, 0), Vector3(end_span, 0.12, 0.13), Color("54757a"))
		_add_cutaway_box(marker, "DoorThreshold", Vector3(0, 0.025, 0), Vector3(opening, 0.035, 0.18), Color("c88b2f"))
	else:
		_add_cutaway_box(marker, "WallSill", Vector3(0, 0.07, 0), Vector3(span, 0.12, 0.13), Color("54757a"))
	cutaway_marker_nodes[edge_key] = marker


func _add_cutaway_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func apply_camera_cutaway(focus_cell: Vector2i, camera_direction: Vector2) -> Dictionary:
	var previously_culled: Array[String] = cutaway_culled_edge_keys.duplicate()
	cutaway_culled_edge_keys.clear()
	cutaway_culled_wall_count = 0
	cutaway_culled_doorway_count = 0
	cutaway_visible_wall_count = 0
	cutaway_visible_doorway_count = 0
	cutaway_open_passage_count = 0
	cutaway_focus_room_index = int(occupancy.get(focus_cell, -1))
	for raw_node: Variant in structural_edge_nodes.values():
		var edge_node := raw_node as Node3D
		if edge_node != null:
			edge_node.visible = true
	for raw_marker: Variant in cutaway_marker_nodes.values():
		var marker := raw_marker as Node3D
		if marker != null:
			marker.visible = bool(marker.get_meta("passage_open", false))
	for junction: Node3D in structural_junction_nodes:
		if is_instance_valid(junction):
			junction.visible = true
	_set_wall_bound_props_visible(true)
	if cutaway_focus_room_index < 0:
		return cutaway_debug_state()
	var viewer_direction := camera_direction.normalized()
	if viewer_direction.length_squared() < 0.01:
		viewer_direction = Vector2.ONE.normalized()
	var edge_keys: Array = visual_edge_records.keys()
	edge_keys.sort()
	for raw_key: Variant in edge_keys:
		var edge_key := str(raw_key)
		var record: Dictionary = visual_edge_records[edge_key]
		var kind := str(record.get("kind", ""))
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		var neighbor: Vector2i = record.get("neighbor", Vector2i.ZERO)
		var passage_open := bool(record.get("passage_open", false))
		var should_cull := passage_open
		if passage_open:
			pass
		elif kind == "outer":
			should_cull = _edge_faces_camera(neighbor - cell, viewer_direction, edge_key in previously_culled)
		elif kind == "door" and not occupancy.has(neighbor):
			should_cull = _edge_faces_camera(neighbor - cell, viewer_direction, edge_key in previously_culled)
		elif kind in ["divider", "door"]:
			var outward := Vector2i.ZERO
			if int(occupancy.get(cell, -1)) == cutaway_focus_room_index:
				outward = neighbor - cell
			elif int(occupancy.get(neighbor, -1)) == cutaway_focus_room_index:
				outward = cell - neighbor
			if outward != Vector2i.ZERO:
				should_cull = _edge_faces_camera(outward, viewer_direction, edge_key in previously_culled)
		var edge_node := structural_edge_nodes.get(edge_key) as Node3D
		if edge_node != null:
			edge_node.visible = not should_cull
		var cutaway_marker := cutaway_marker_nodes.get(edge_key) as Node3D
		if cutaway_marker != null:
			cutaway_marker.visible = should_cull
		if kind == "door":
			if passage_open:
				cutaway_culled_edge_keys.append(edge_key)
				cutaway_open_passage_count += 1
			elif should_cull:
				cutaway_culled_edge_keys.append(edge_key)
				cutaway_culled_doorway_count += 1
			else:
				cutaway_visible_doorway_count += 1
		elif kind in ["outer", "divider"]:
			if should_cull:
				cutaway_culled_edge_keys.append(edge_key)
				cutaway_culled_wall_count += 1
			else:
				cutaway_visible_wall_count += 1
	_update_cutaway_junction_visibility()
	_update_wall_bound_prop_visibility()
	return cutaway_debug_state()


func _edge_faces_camera(outward: Vector2i, viewer_direction: Vector2, was_culled: bool = false) -> bool:
	var normal := Vector2(float(outward.x), float(outward.y)).normalized()
	var threshold := 0.28 if was_culled else 0.42
	return normal.dot(viewer_direction) > threshold


func _update_cutaway_junction_visibility() -> void:
	for junction: Node3D in structural_junction_nodes:
		if not is_instance_valid(junction):
			continue
		var incident_edges: Array = junction.get_meta("junction_edge_keys", [])
		var has_visible_edge := incident_edges.is_empty()
		for raw_key: Variant in incident_edges:
			if not cutaway_culled_edge_keys.has(str(raw_key)):
				has_visible_edge = true
				break
		junction.visible = has_visible_edge


func _set_wall_bound_props_visible(visible: bool) -> void:
	for raw_nodes: Variant in wall_bound_prop_nodes.values():
		for prop: Node3D in raw_nodes:
			if is_instance_valid(prop):
				prop.visible = visible


func _update_wall_bound_prop_visibility() -> void:
	for raw_key: Variant in wall_bound_prop_nodes.keys():
		var edge_key := str(raw_key)
		var edge_is_visible := not cutaway_culled_edge_keys.has(edge_key)
		for prop: Node3D in wall_bound_prop_nodes[edge_key]:
			if is_instance_valid(prop):
				prop.visible = edge_is_visible


func cutaway_debug_state() -> Dictionary:
	var focus_size := 0
	if cutaway_focus_room_index >= 0 and cutaway_focus_room_index < rooms.size():
		focus_size = int(rooms[cutaway_focus_room_index].get("size", 0))
	return {
		"focus_room_index": cutaway_focus_room_index,
		"focus_room_size": focus_size,
		"culled_walls": cutaway_culled_wall_count,
		"culled_doors": cutaway_culled_doorway_count,
		"visible_walls": cutaway_visible_wall_count,
		"visible_doors": cutaway_visible_doorway_count,
		"open_doors": cutaway_open_passage_count,
		"edge_total": visual_edge_records.size(),
		"external_walls": external_wall_count,
		"divider_walls": divider_wall_count,
		"doorways": doorway_count,
	}


func cutaway_debug_summary() -> String:
	var state := cutaway_debug_state()
	return "PCG %d格房 · 剔除%d墙/%d门 · 可见%d墙/%d门 · 开放%d门 · 边%d=%d外+%d隔+%d门" % [
		int(state["focus_room_size"]),
		int(state["culled_walls"]),
		int(state["culled_doors"]),
		int(state["visible_walls"]),
		int(state["visible_doors"]),
		int(state["open_doors"]),
		int(state["edge_total"]),
		int(state["external_walls"]),
		int(state["divider_walls"]),
		int(state["doorways"]),
	]


func open_passages_are_clear() -> bool:
	var open_records := 0
	for raw_key: Variant in visual_edge_records.keys():
		var edge_key := str(raw_key)
		var record: Dictionary = visual_edge_records[edge_key]
		if not bool(record.get("passage_open", false)):
			continue
		open_records += 1
		var node := structural_edge_nodes.get(edge_key) as Node3D
		var marker := cutaway_marker_nodes.get(edge_key) as Node3D
		if node == null or not bool(node.get_meta("passage_open", false)):
			return false
		if not node.find_children("*", "MeshInstance3D", true, false).is_empty():
			return false
		if marker == null or not marker.visible or marker.get_node_or_null("DoorThreshold") == null:
			return false
	return open_records == open_passage_count


func structural_edge_metadata_is_complete() -> bool:
	if structural_edge_nodes.size() != visual_edge_records.size() or cutaway_marker_nodes.size() != visual_edge_records.size():
		return false
	for raw_key: Variant in visual_edge_records.keys():
		var edge_key := str(raw_key)
		var node := structural_edge_nodes.get(edge_key) as Node3D
		if node == null or str(node.get_meta("edge_key", "")) != edge_key:
			return false
	return true


func cutaway_markers_match_culled_edges() -> bool:
	for raw_key: Variant in visual_edge_records.keys():
		var edge_key := str(raw_key)
		var marker := cutaway_marker_nodes.get(edge_key) as Node3D
		if marker == null or marker.visible != cutaway_culled_edge_keys.has(edge_key):
			return false
	return true


func _register_edge_junctions(cell: Vector2i, side: int, center: Vector2, elevation: float, room_index: int, junctions: Dictionary) -> void:
	if not use_kaykit_room_shell:
		return
	var direction: Vector2i = DIRS[side]
	var edge_key := _edge_key(cell, cell + direction)
	var edge_center := _cell_world(cell, center) + Vector3(float(direction.x) * CELL * 0.5, elevation + 0.025, float(direction.y) * CELL * 0.5)
	var tangent: Vector3 = Vector3.RIGHT if side in [0, 2] else Vector3.BACK
	for raw_sign: Variant in [-1.0, 1.0]:
		var sign_value := float(raw_sign)
		var position: Vector3 = edge_center + tangent * CELL * 0.5 * sign_value
		var key := "%0.3f,%0.3f" % [position.x, position.z]
		if not junctions.has(key):
			junctions[key] = {"position": Vector3(position.x, elevation + 0.025, position.z), "min_elevation": elevation, "max_elevation": elevation, "room_index": room_index, "edge_keys": {edge_key: true}}
			continue
		var record: Dictionary = junctions[key]
		record["min_elevation"] = minf(float(record["min_elevation"]), elevation)
		record["max_elevation"] = maxf(float(record["max_elevation"]), elevation)
		var record_edge_keys: Dictionary = record.get("edge_keys", {})
		record_edge_keys[edge_key] = true
		record["edge_keys"] = record_edge_keys
		junctions[key] = record


func _spawn_edge_junctions(junctions: Dictionary) -> void:
	if not use_kaykit_room_shell:
		return
	var keys: Array = junctions.keys()
	keys.sort()
	for raw_key: Variant in keys:
		var key := str(raw_key)
		var record: Dictionary = junctions[key]
		var min_elevation := float(record["min_elevation"])
		var max_elevation := float(record["max_elevation"])
		var height := KAYKIT_WALL_HEIGHT + max_elevation - min_elevation
		var position: Vector3 = record["position"]
		position.y = min_elevation + 0.025
		var junction: Node3D = null
		if use_toy_show_cardboard_shell:
			junction = _add_cardboard_junction("Junction_%s" % key, position, height, int(record["room_index"]), (record.get("edge_keys", {}) as Dictionary).keys())
		else:
			var scale_value := Vector3(KAYKIT_JUNCTION_WIDTH / 1.5, height / 4.0, KAYKIT_JUNCTION_WIDTH / 1.5)
			junction = _add_model("Junction_%s" % key, KAYKIT_ROOT + "pillar.gltf.glb", position, scale_value, 0.0, int(record["room_index"]))
		if junction != null:
			junction.set_meta("structure_kind", "junction")
			junction.set_meta("junction_edge_keys", (record.get("edge_keys", {}) as Dictionary).keys())
			structural_junction_nodes.append(junction)
		junction_count += 1


func _build_room_props(center: Vector2) -> void:
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var cells: Array[Vector2i] = room["cells"]
		if cells.is_empty():
			continue
		if not bool(room.get("visited", true)):
			if show_room_ids:
				_add_room_label(room, room_index, center)
			continue
		var request := RoomPropCatalog.placement_request(room, room_index, generation_seed)
		var candidates := _room_prop_slot_candidates(room_index, center)
		var room_rng := RandomNumberGenerator.new()
		room_rng.seed = int(request["seed"])
		var room_records: Array[Dictionary] = []
		var requested_items: Array = request.get("items", [])
		for slot_index in range(requested_items.size()):
			var requested_item: Dictionary = requested_items[slot_index]
			var requested_slot := str(requested_item.get("slot", ""))
			var requested_asset_id := str(requested_item.get("asset_id", ""))
			var placement := _choose_prop_placement(str(request["theme"]), requested_slot, candidates, room_records, room_rng, requested_asset_id)
			if placement.is_empty():
				placement = _choose_prop_fallback(str(request["theme"]), candidates, room_records, room_rng)
			if placement.is_empty():
				prop_placement_issues.append("room %s could not fill prop slot %d" % [str(room.get("id", room_index)), slot_index])
				continue
			var candidate: Dictionary = placement["candidate"]
			var entry: Dictionary = placement["entry"]
			var world: Vector3 = candidate["position"]
			var yaw := float(candidate.get("yaw", 0.0))
			if str(candidate.get("slot", "")) in [RoomPropCatalog.SLOT_MAIN, RoomPropCatalog.SLOT_ACCENT]:
				yaw += float(room_rng.randi_range(0, 3)) * PI * 0.5
			var node := _add_model(
				"RoomProp_%02d_%02d_%s" % [room_index, room_records.size(), str(entry["id"])],
				str(entry["path"]), world, Vector3.ONE * float(entry["scale"]), yaw, room_index
			)
			if node == null:
				prop_placement_issues.append("asset failed to instantiate: %s" % str(entry["path"]))
				continue
			var handmade_finish := RoomPropCatalog.handmade_finish_for(str(entry["id"]))
			var finish_surface_count := _apply_handmade_prop_finish(node, str(entry["id"]), handmade_finish)
			if finish_surface_count <= 0:
				prop_placement_issues.append("asset has no surface for handmade finish: %s" % str(entry["path"]))
			var edge_key := str(candidate.get("edge_key", ""))
			var wall_follow := bool(entry.get("wall_follow", false)) and not edge_key.is_empty()
			var record := {
				"room_index": room_index,
				"room_id": str(room.get("id", "R%02d" % room_index)),
				"theme": str(request["theme"]),
				"composition_id": str(request.get("composition_id", "fallback")),
				"requested_asset_id": requested_asset_id,
				"composition_matched": requested_asset_id.is_empty() or requested_asset_id == str(entry["id"]),
				"asset_id": str(entry["id"]),
				"path": str(entry["path"]),
				"node_name": node.name,
				"handmade_finish": handmade_finish,
				"finish_surface_count": finish_surface_count,
				"slot": str(candidate["slot"]),
				"cell": candidate["cell"],
				"position": world,
				"yaw": yaw,
				"scale": float(entry["scale"]),
				"footprint": entry["footprint"],
				"rotation_rule": "wall_inward" if not edge_key.is_empty() else "quarter_turns",
				"edge_key": edge_key,
				"wall_follow": wall_follow,
				"tall": bool(entry.get("tall", false)),
				"overlay": bool(entry.get("overlay", false)),
			}
			node.set_meta("room_prop_record", record)
			room_records.append(record)
			prop_placement_records.append(record)
			if wall_follow:
				var bound: Array = wall_bound_prop_nodes.get(edge_key, [])
				bound.append(node)
				wall_bound_prop_nodes[edge_key] = bound
			prop_count += 1
		_validate_room_prop_count(room, room_records.size())
		_build_room_interaction_slots(room_index, candidates, room_records)
		_build_room_show_evidence(room_index)
		_build_room_production_fixture(room_index)
		if show_room_ids:
			_add_room_label(room, room_index, center)


func _room_prop_slot_candidates(room_index: int, center: Vector2) -> Dictionary:
	var result := {
		RoomPropCatalog.SLOT_MAIN: [],
		RoomPropCatalog.SLOT_WALL: [],
		RoomPropCatalog.SLOT_CORNER: [],
		RoomPropCatalog.SLOT_ACCENT: [],
	}
	var room: Dictionary = rooms[room_index]
	var cells: Array[Vector2i] = room["cells"]
	var room_cells: Dictionary = {}
	for cell: Vector2i in cells:
		room_cells[cell] = true
	var elevation := float(room.get("elevation", 0.0))
	for cell: Vector2i in cells:
		var base := _cell_world(cell, center) + Vector3(0, elevation + 0.045, 0)
		(result[RoomPropCatalog.SLOT_MAIN] as Array).append({"slot": RoomPropCatalog.SLOT_MAIN, "cell": cell, "position": base, "yaw": 0.0, "edge_key": ""})
		for offset: Vector2 in [Vector2(-0.25, -0.20), Vector2(0.25, 0.20)]:
			(result[RoomPropCatalog.SLOT_ACCENT] as Array).append({"slot": RoomPropCatalog.SLOT_ACCENT, "cell": cell, "position": base + Vector3(offset.x * CELL, 0, offset.y * CELL), "yaw": 0.0, "edge_key": ""})
		var wall_sides: Array[int] = []
		for side in range(DIRS.size()):
			var direction: Vector2i = DIRS[side]
			var neighbor := cell + direction
			if room_cells.has(neighbor):
				continue
			var edge_key := _edge_key(cell, neighbor)
			var edge_record: Dictionary = visual_edge_records.get(edge_key, {})
			if str(edge_record.get("kind", "")) not in ["outer", "divider"]:
				continue
			wall_sides.append(side)
			(result[RoomPropCatalog.SLOT_WALL] as Array).append({
				"slot": RoomPropCatalog.SLOT_WALL,
				"cell": cell,
				"position": base + Vector3(float(direction.x) * CELL * 0.31, 0, float(direction.y) * CELL * 0.31),
				"yaw": _direction_yaw(-direction),
				"edge_key": edge_key,
			})
		for side in wall_sides:
			var next_side := (side + 1) % DIRS.size()
			if not next_side in wall_sides:
				continue
			var direction_a: Vector2i = DIRS[side]
			var direction_b: Vector2i = DIRS[next_side]
			var edge_key := _edge_key(cell, cell + direction_a)
			(result[RoomPropCatalog.SLOT_CORNER] as Array).append({
				"slot": RoomPropCatalog.SLOT_CORNER,
				"cell": cell,
				"position": base + Vector3(float(direction_a.x + direction_b.x) * CELL * 0.27, 0, float(direction_a.y + direction_b.y) * CELL * 0.27),
				"yaw": _direction_yaw(-direction_a),
				"edge_key": edge_key,
			})
	return result


func _choose_prop_placement(theme: String, slot: String, candidates: Dictionary, placed: Array[Dictionary], room_rng: RandomNumberGenerator, preferred_asset_id: String = "") -> Dictionary:
	var entries := RoomPropCatalog.entries_for(theme, slot)
	for index in range(entries.size() - 1, -1, -1):
		if bool(entries[index].get("repeatable", false)):
			continue
		for previous: Dictionary in placed:
			if str(previous.get("asset_id", "")) == str(entries[index].get("id", "")):
				entries.remove_at(index)
				break
	var slot_candidates: Array = candidates.get(slot, []).duplicate()
	_shuffle_array(slot_candidates, room_rng)
	if not preferred_asset_id.is_empty():
		for preferred_index in range(entries.size() - 1, -1, -1):
			var preferred_entry: Dictionary = entries[preferred_index]
			if str(preferred_entry.get("id", "")) != preferred_asset_id:
				continue
			entries.remove_at(preferred_index)
			for candidate: Dictionary in slot_candidates:
				if _prop_candidate_is_clear(candidate, preferred_entry, placed):
					(candidates[slot] as Array).erase(candidate)
					return {"entry": preferred_entry, "candidate": candidate}
			break
	while not entries.is_empty():
		var entry := _take_weighted_entry(entries, room_rng)
		for candidate: Dictionary in slot_candidates:
			if _prop_candidate_is_clear(candidate, entry, placed):
				(candidates[slot] as Array).erase(candidate)
				return {"entry": entry, "candidate": candidate}
	return {}


func _choose_prop_fallback(theme: String, candidates: Dictionary, placed: Array[Dictionary], room_rng: RandomNumberGenerator) -> Dictionary:
	for slot in [RoomPropCatalog.SLOT_ACCENT, RoomPropCatalog.SLOT_CORNER, RoomPropCatalog.SLOT_WALL, RoomPropCatalog.SLOT_MAIN]:
		var placement := _choose_prop_placement(theme, slot, candidates, placed, room_rng)
		if not placement.is_empty():
			return placement
	return {}


func _shuffle_array(values: Array, room_rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := room_rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary


func _take_weighted_entry(entries: Array[Dictionary], room_rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0
	for entry: Dictionary in entries:
		total_weight += maxi(1, int(entry.get("weight", 1)))
	var roll := room_rng.randi_range(1, maxi(1, total_weight))
	for index in range(entries.size()):
		roll -= maxi(1, int(entries[index].get("weight", 1)))
		if roll <= 0:
			var chosen: Dictionary = entries[index]
			entries.remove_at(index)
			return chosen
	return entries.pop_back()


func _prop_candidate_is_clear(candidate: Dictionary, entry: Dictionary, placed: Array[Dictionary]) -> bool:
	var position: Vector3 = candidate["position"]
	var footprint: Vector2 = entry["footprint"]
	var radius := maxf(footprint.x, footprint.y) * 0.5
	var room_index := int(occupancy.get(candidate["cell"], -1))
	if room_index < 0:
		return false
	for raw_record: Variant in visual_edge_records.values():
		var edge_record: Dictionary = raw_record
		if str(edge_record.get("kind", "")) != "door":
			continue
		var edge_cell: Vector2i = edge_record["cell"]
		var edge_neighbor: Vector2i = edge_record["neighbor"]
		if int(occupancy.get(edge_cell, -2)) != room_index and int(occupancy.get(edge_neighbor, -2)) != room_index:
			continue
		var midpoint := (_cell_world(edge_cell, layout_center) + _cell_world(edge_neighbor, layout_center)) * 0.5
		if Vector2(position.x - midpoint.x, position.z - midpoint.z).length() < radius + 0.30:
			return false
	if bool(entry.get("overlay", false)):
		return true
	for previous: Dictionary in placed:
		if bool(previous.get("overlay", false)):
			continue
		var previous_position: Vector3 = previous["position"]
		var previous_footprint: Vector2 = previous["footprint"]
		var previous_radius := maxf(previous_footprint.x, previous_footprint.y) * 0.5
		if Vector2(position.x - previous_position.x, position.z - previous_position.z).length() < (radius + previous_radius) * 0.55:
			return false
	return true


func _validate_room_prop_count(room: Dictionary, count: int) -> void:
	var allowed := RoomPropCatalog.count_range_for_size(int(room.get("size", 1)))
	if count < allowed.x or count > allowed.y:
		prop_placement_issues.append("room %s has %d props outside %d-%d" % [str(room.get("id", "?")), count, allowed.x, allowed.y])


func _build_room_interaction_slots(room_index: int, candidates: Dictionary, room_records: Array[Dictionary]) -> void:
	var room: Dictionary = rooms[room_index]
	for cell: Vector2i in room["cells"]:
		_build_cell_interaction_slots(room_index, cell, candidates, room_records)


func _build_room_show_evidence(room_index: int) -> void:
	var room_slots := interaction_slots_for_room_index(room_index)
	if room_slots.is_empty():
		show_evidence_issues.append("room %d has no actor slot for its production mark" % room_index)
		return
	var room: Dictionary = rooms[room_index]
	var request := RoomPropCatalog.placement_request(room, room_index, generation_seed)
	var selected_slot: Dictionary = room_slots[posmod(int(request.get("seed", 0)), room_slots.size())]
	var position: Vector3 = selected_slot["position"] + Vector3.UP * 0.008
	var palette := [
		[Color("e83f8f"), Color("67d6d1")],
		[Color("f4c64e"), Color("e83f8f")],
		[Color("67d6d1"), Color("f4c64e")],
	]
	var colors: Array = palette[posmod(int(request.get("seed", 0)), palette.size())]
	var marker := Node3D.new()
	marker.name = "ShowEvidence_%02d_ActorMark" % room_index
	marker.rotation.y = PI * 0.25
	_add_show_evidence_box(marker, "TapeA", Vector3.ZERO, Vector3(0.25, 0.009, 0.038), colors[0])
	_add_show_evidence_box(marker, "TapeB", Vector3.ZERO, Vector3(0.038, 0.010, 0.25), colors[1])
	var record := {
		"room_index": room_index,
		"room_id": str(room.get("id", "R%02d" % room_index)),
		"cell": selected_slot.get("cell", Vector2i.ZERO),
		"slot_index": int(selected_slot.get("slot_index", -1)),
		"position": selected_slot["position"],
		"kind": "actor_mark",
		"node_name": marker.name,
		"affects_topology": false,
	}
	marker.set_meta("show_evidence_record", record)
	_add_to_visual_root(marker, room_index, position)
	show_evidence_records.append(record)


func _add_show_evidence_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _build_room_production_fixture(room_index: int) -> void:
	var wall_candidates: Array[Dictionary] = []
	var doorway_candidates: Array[Dictionary] = []
	for raw_key: Variant in visual_edge_records.keys():
		var edge_key := str(raw_key)
		var edge_record: Dictionary = visual_edge_records[edge_key]
		var edge_kind := str(edge_record.get("kind", ""))
		if edge_kind not in ["outer", "divider", "door"] or bool(edge_record.get("passage_open", false)):
			continue
		var cell: Vector2i = edge_record.get("cell", Vector2i.ZERO)
		var neighbor: Vector2i = edge_record.get("neighbor", Vector2i.ZERO)
		var outward := Vector2i.ZERO
		if int(occupancy.get(cell, -1)) == room_index:
			outward = neighbor - cell
		elif int(occupancy.get(neighbor, -1)) == room_index:
			outward = cell - neighbor
		if outward == Vector2i.ZERO:
			continue
		var candidate := {"edge_key": edge_key, "cell": cell if int(occupancy.get(cell, -1)) == room_index else neighbor, "outward": outward, "edge_kind": edge_kind}
		if edge_kind == "door":
			doorway_candidates.append(candidate)
		else:
			wall_candidates.append(candidate)
	wall_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["edge_key"]) < str(b["edge_key"]))
	doorway_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["edge_key"]) < str(b["edge_key"]))
	if wall_candidates.is_empty():
		wall_candidates = doorway_candidates
	if wall_candidates.is_empty():
		production_fixture_issues.append("room %d has no wall or closed doorway for its production fixture" % room_index)
		return
	var room: Dictionary = rooms[room_index]
	var request := RoomPropCatalog.placement_request(room, room_index, generation_seed)
	var seed_value := int(request.get("seed", 0))
	var candidate: Dictionary = wall_candidates[posmod(seed_value, wall_candidates.size())]
	var cell: Vector2i = candidate["cell"]
	var outward: Vector2i = candidate["outward"]
	var edge_key := str(candidate["edge_key"])
	var edge_kind := str(candidate["edge_kind"])
	var cell_center := _cell_world(cell, layout_center)
	var fixture_height := KAYKIT_WALL_HEIGHT * (0.86 if edge_kind == "door" else 0.62)
	var position := cell_center + Vector3(float(outward.x) * CELL * 0.5, float(room.get("elevation", 0.0)) + fixture_height, float(outward.y) * CELL * 0.5)
	position -= Vector3(float(outward.x), 0, float(outward.y)) * (CARDBOARD_PANEL_THICKNESS * 0.58)
	var kinds := ["cue_card", "fake_window", "on_air"]
	var kind := "cue_card" if edge_kind == "door" else str(kinds[posmod(floori(float(seed_value) / 7.0), kinds.size())])
	var theme := str(request.get("theme", ""))
	var anomaly_id := RoomPropCatalog.anomaly_for_theme(theme)
	var fixture := _add_production_fixture("ProductionFixture_%02d_%s" % [room_index, kind], position, _direction_yaw(outward), room_index, kind, anomaly_id)
	if fixture == null:
		production_fixture_issues.append("room %d failed to create production fixture" % room_index)
		return
	var record := {
		"room_index": room_index,
		"room_id": str(room.get("id", "R%02d" % room_index)),
		"theme": theme,
		"kind": kind,
		"anomaly_id": anomaly_id,
		"edge_key": edge_key,
		"edge_kind": edge_kind,
		"node_name": fixture.name,
		"affects_topology": false,
	}
	fixture.set_meta("production_fixture_record", record)
	production_fixture_records.append(record)
	var bound: Array = wall_bound_prop_nodes.get(edge_key, [])
	bound.append(fixture)
	wall_bound_prop_nodes[edge_key] = bound


func _add_production_fixture(node_name: String, position: Vector3, yaw: float, room_index: int, kind: String, anomaly_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.rotation.y = yaw
	match kind:
		"cue_card":
			_add_cardboard_box(root, "Slate", Vector3.ZERO, Vector3(0.30, 0.20, 0.025), Color("25303b"), false)
			_add_cardboard_box(root, "SlateTop", Vector3(0, 0.09, -0.018), Vector3(0.30, 0.045, 0.022), Color("f1c24b"), false)
			_add_cardboard_box(root, "SlateLine", Vector3(0, -0.025, -0.018), Vector3(0.19, 0.018, 0.022), Color("f2e6c9"), false)
		"fake_window":
			_add_cardboard_box(root, "WindowBlue", Vector3.ZERO, Vector3(0.31, 0.23, 0.025), Color("71c7cf"), false)
			_add_cardboard_box(root, "FrameTop", Vector3(0, 0.115, -0.018), Vector3(0.35, 0.035, 0.025), Color("f2e6c9"), false)
			_add_cardboard_box(root, "FrameBottom", Vector3(0, -0.115, -0.018), Vector3(0.35, 0.035, 0.025), Color("f2e6c9"), false)
			_add_cardboard_box(root, "FrameLeft", Vector3(-0.16, 0, -0.018), Vector3(0.035, 0.24, 0.025), Color("f2e6c9"), false)
			_add_cardboard_box(root, "FrameRight", Vector3(0.16, 0, -0.018), Vector3(0.035, 0.24, 0.025), Color("f2e6c9"), false)
		"on_air":
			_add_cardboard_box(root, "OnAirBoard", Vector3.ZERO, Vector3(0.31, 0.17, 0.025), Color("c93471"), false)
			for index in range(3):
				var lamp_color := Color("f6dd67") if index != 1 else Color("70d4ca")
				_add_cardboard_box(root, "Lamp_%d" % index, Vector3(-0.09 + float(index) * 0.09, 0, -0.022), Vector3(0.038, 0.038, 0.026), lamp_color, false)
		_:
			return null
	_add_theme_anomaly_cue(root, anomaly_id)
	_add_to_visual_root(root, room_index, position)
	return root


func _add_theme_anomaly_cue(fixture: Node3D, anomaly_id: String) -> void:
	var cue := Node3D.new()
	cue.name = "AnomalyCue"
	cue.visible = false
	cue.position = Vector3(0.0, -0.18, 0.09)
	cue.scale = Vector3.ONE * 1.22
	cue.set_meta("anomaly_id", anomaly_id)
	match anomaly_id:
		"applause_loop":
			for index in range(3):
				var x := -0.11 + float(index) * 0.11
				_add_cardboard_box(cue, "ApplausePalm_%d" % index, Vector3(x, 0.0, -0.060), Vector3(0.070, 0.105, 0.018), Color("f2c06b"), false)
				_add_cardboard_box(cue, "ApplauseBeat_%d" % index, Vector3(x, 0.078, -0.061), Vector3(0.025, 0.045, 0.019), Color("e86f8f"), false)
		"wrong_dream_eyes":
			for index in range(2):
				var x := -0.075 + float(index) * 0.15
				_add_cardboard_box(cue, "DreamEye_%d" % index, Vector3(x, 0.015, -0.062), Vector3(0.105, 0.060, 0.020), Color("f2e8cb"), false)
				_add_cardboard_box(cue, "DreamPupil_%d" % index, Vector3(x + 0.018, 0.015, -0.076), Vector3(0.030, 0.040, 0.018), Color("283443"), false)
		"cold_oven_icicles":
			for index in range(4):
				var height := 0.065 + float(index % 2) * 0.045
				_add_cardboard_box(cue, "Icicle_%d" % index, Vector3(-0.12 + float(index) * 0.08, -height * 0.5, -0.064), Vector3(0.030, height, 0.020), Color("83d8df"), false)
		"rewritten_cue_card":
			_add_cardboard_box(cue, "ReplacementCard", Vector3(0.035, -0.015, -0.064), Vector3(0.275, 0.155, 0.018), Color("f3e4bd"), false)
			for index in range(3):
				_add_cardboard_box(cue, "Rewrite_%d" % index, Vector3(0.005 + float(index % 2) * 0.035, 0.040 - float(index) * 0.045, -0.078), Vector3(0.185 - float(index) * 0.025, 0.014, 0.012), Color("c7436e"), false)
		"plastic_rain":
			for index in range(5):
				var y := 0.065 - float(index % 3) * 0.055
				_add_cardboard_box(cue, "RainStrip_%d" % index, Vector3(-0.13 + float(index) * 0.065, y, -0.064), Vector3(0.018, 0.095, 0.014), Color("69cdd5"), false)
		"backstage_knocking":
			_add_cardboard_box(cue, "KnockHand", Vector3(-0.035, 0.0, -0.064), Vector3(0.095, 0.120, 0.020), Color("75517d"), false)
			for index in range(3):
				_add_cardboard_box(cue, "KnockBeat_%d" % index, Vector3(0.055 + float(index) * 0.045, 0.045 - float(index) * 0.045, -0.064), Vector3(0.032, 0.012, 0.018), Color("f0c15b"), false)
		_:
			production_fixture_issues.append("unknown room anomaly: %s" % anomaly_id)
	fixture.add_child(cue)


func _build_cell_interaction_slots(room_index: int, cell: Vector2i, candidates: Dictionary, room_records: Array[Dictionary]) -> void:
	var room: Dictionary = rooms[room_index]
	var room_id := str(room.get("id", "R%02d" % room_index))
	var cell_records: Array[Dictionary] = []
	for prop_record: Dictionary in room_records:
		if prop_record.get("cell", Vector2i.ZERO) == cell:
			cell_records.append(prop_record)
	var slots: Array[Dictionary] = []
	for preferred_kind in ["sit", "cook", "work", "tend", "gather", "browse", "rest", "warm"]:
		for prop_record: Dictionary in cell_records:
			var profile := RoomPropCatalog.interaction_profile(str(prop_record.get("asset_id", "")))
			if str(profile.get("kind", "")) != preferred_kind:
				continue
			var capacity := int(profile.get("capacity", 1))
			var spacing := float(profile.get("spacing", 0.0))
			var prop_position: Vector3 = prop_record["position"]
			var approach_direction := Vector3(sin(float(prop_record["yaw"])), 0, cos(float(prop_record["yaw"]))).normalized()
			if not str(prop_record.get("edge_key", "")).is_empty():
				var cell_center := _cell_world(prop_record["cell"], layout_center)
				approach_direction = (cell_center - prop_position).normalized()
				approach_direction.y = 0.0
			var lateral := Vector3(approach_direction.z, 0, -approach_direction.x)
			for occupant_index in range(capacity):
				var lateral_offset := (float(occupant_index) - float(capacity - 1) * 0.5) * spacing
				var approach_distance := absf(float((profile.get("approach", Vector3(0, 0, 0.30)) as Vector3).z))
				var position := prop_position + approach_direction * approach_distance + lateral * lateral_offset
				var anchor_height := float((profile.get("anchor", Vector3.ZERO) as Vector3).y)
				var anchor_position := prop_position + lateral * lateral_offset + Vector3.UP * anchor_height
				if not _interaction_position_is_in_cell(position, cell):
					continue
				if not _interaction_position_is_clear(position, room_index, room_records, prop_record, slots):
					continue
				slots.append({
					"room_index": room_index,
					"room_id": room_id,
					"cell": cell,
					"kind": preferred_kind,
					"pose": str(profile.get("pose", "stand")),
					"asset_id": str(prop_record.get("asset_id", "")),
					"owner_position": prop_position,
					"position": position,
					"anchor_position": anchor_position,
					"facing_yaw": atan2(prop_position.x - position.x, prop_position.z - position.z),
				})
				if slots.size() >= 4:
					break
			if slots.size() >= 4:
				break
		if slots.size() >= 4:
			break
	var fallback_candidates: Array = []
	for slot_type in [RoomPropCatalog.SLOT_MAIN, RoomPropCatalog.SLOT_ACCENT, RoomPropCatalog.SLOT_CORNER, RoomPropCatalog.SLOT_WALL]:
		for candidate: Dictionary in candidates.get(slot_type, []):
			if candidate.get("cell", Vector2i.ZERO) == cell:
				fallback_candidates.append(candidate)
	var cell_center := _cell_world(cell, layout_center) + Vector3(0, float(room.get("elevation", 0.0)) + 0.045, 0)
	for candidate: Dictionary in fallback_candidates:
		if slots.size() >= 4:
			break
		var position: Vector3 = candidate["position"]
		if not _interaction_position_is_clear(position, room_index, room_records, {}, slots):
			continue
		slots.append({
			"room_index": room_index,
			"room_id": room_id,
			"cell": cell,
			"kind": "stand",
			"pose": "stand",
			"asset_id": "",
			"position": position,
			"anchor_position": position,
			"facing_yaw": atan2(cell_center.x - position.x, cell_center.z - position.z),
		})
	if slots.size() < 4:
		for offset_y in [-0.36, -0.18, 0.0, 0.18, 0.36]:
			for offset_x in [-0.36, -0.18, 0.0, 0.18, 0.36]:
				if slots.size() >= 4:
					break
				var position := cell_center + Vector3(float(offset_x) * CELL, 0, float(offset_y) * CELL)
				if not _interaction_position_is_clear(position, room_index, room_records, {}, slots):
					continue
				slots.append({
					"room_index": room_index,
					"room_id": room_id,
					"cell": cell,
					"kind": "stand",
					"pose": "stand",
					"asset_id": "",
					"position": position,
					"anchor_position": position,
					"facing_yaw": atan2(cell_center.x - position.x, cell_center.z - position.z),
				})
			if slots.size() >= 4:
				break
	if slots.size() < 4:
		interaction_slot_issues.append("room %s cell %s only produced %d interaction slots" % [room_id, str(cell), slots.size()])
	for slot_index in range(mini(4, slots.size())):
		var slot: Dictionary = slots[slot_index]
		slot["slot_index"] = slot_index
		interaction_slot_records.append(slot)
		var marker := Node3D.new()
		marker.name = "InteractionSlot_%02d_%d_%d_%02d" % [room_index, cell.x, cell.y, slot_index]
		marker.set_meta("interaction_slot", slot)
		_add_to_visual_root(marker, room_index, slot["position"])


func _interaction_position_is_in_cell(position: Vector3, cell: Vector2i) -> bool:
	var center := _cell_world(cell, layout_center)
	var half_extent := CELL * 0.49
	return absf(position.x - center.x) <= half_extent and absf(position.z - center.z) <= half_extent


func _interaction_position_is_clear(position: Vector3, room_index: int, room_records: Array[Dictionary], owner: Dictionary, slots: Array[Dictionary]) -> bool:
	for raw_edge: Variant in visual_edge_records.values():
		var edge_record: Dictionary = raw_edge
		if str(edge_record.get("kind", "")) != "door":
			continue
		var edge_cell: Vector2i = edge_record["cell"]
		var edge_neighbor: Vector2i = edge_record["neighbor"]
		if int(occupancy.get(edge_cell, -2)) != room_index and int(occupancy.get(edge_neighbor, -2)) != room_index:
			continue
		var midpoint := (_cell_world(edge_cell, layout_center) + _cell_world(edge_neighbor, layout_center)) * 0.5
		if Vector2(position.x - midpoint.x, position.z - midpoint.z).length() < 0.38:
			return false
	for prop_record: Dictionary in room_records:
		if not owner.is_empty() and prop_record["position"].is_equal_approx(owner.get("position", Vector3.INF)):
			continue
		if bool(prop_record.get("overlay", false)):
			continue
		var prop_position: Vector3 = prop_record["position"]
		var footprint: Vector2 = prop_record["footprint"]
		var prop_radius := maxf(footprint.x, footprint.y) * 0.5
		if Vector2(position.x - prop_position.x, position.z - prop_position.z).length() < prop_radius + 0.14:
			return false
	for slot: Dictionary in slots:
		var slot_position: Vector3 = slot["position"]
		var minimum_distance := 0.25
		if not owner.is_empty():
			var slot_owner: Vector3 = slot.get("owner_position", Vector3.INF)
			var owner_position: Vector3 = owner.get("position", Vector3.ZERO)
			if slot_owner.is_equal_approx(owner_position):
				minimum_distance = 0.16
		if Vector2(position.x - slot_position.x, position.z - slot_position.z).length() < minimum_distance:
			return false
	return true


func _room_center_world(room: Dictionary) -> Vector3:
	var center := Vector3.ZERO
	var cells: Array[Vector2i] = room["cells"]
	for cell: Vector2i in cells:
		center += _cell_world(cell, layout_center)
	center /= maxf(1.0, float(cells.size()))
	center.y = float(room.get("elevation", 0.0)) + 0.045
	return center


func _build_room_state_overlays(center: Vector2) -> void:
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var cells: Array[Vector2i] = room["cells"]
		var visited := bool(room.get("visited", true))
		var completed := bool(room.get("completed", false))
		var is_current := bool(room.get("is_current", false))
		if not visited:
			for cell: Vector2i in cells:
				var elevation := float(room.get("elevation", 0.0))
				_add_box("UnvisitedCover_%d_%d" % [cell.x, cell.y], _cell_world(cell, center) + Vector3(0, elevation + 0.14, 0), Vector3(CELL * 0.88, 0.08, CELL * 0.88), Color("17242a"), room_index)
		var outline_color := Color.TRANSPARENT
		if is_current:
			outline_color = Color("f3b52b")
		elif not visited:
			outline_color = Color("6b7d84")
		elif completed:
			outline_color = Color("55aa91")
		if outline_color.a > 0.0:
			_add_room_state_outline(room, room_index, center, outline_color)


func _add_room_state_outline(room: Dictionary, room_index: int, center: Vector2, color: Color) -> void:
	var cells: Array[Vector2i] = room["cells"]
	var cell_set: Dictionary = {}
	for cell: Vector2i in cells:
		cell_set[cell] = true
	for cell: Vector2i in cells:
		var elevation := float(room.get("elevation", 0.0))
		for direction: Vector2i in DIRS:
			if cell_set.has(cell + direction):
				continue
			var position := _cell_world(cell, center) + Vector3(float(direction.x) * CELL * 0.47, elevation + 0.20, float(direction.y) * CELL * 0.47)
			var size := Vector3(0.065, 0.045, CELL * 0.84) if direction.x != 0 else Vector3(CELL * 0.84, 0.045, 0.065)
			_add_box("RoomStateEdge_%d_%d_%d_%d" % [room_index, cell.x, cell.y, DIRS.find(direction)], position, size, color, room_index)


func _add_room_label(room: Dictionary, room_index: int, center: Vector2) -> void:
	var cells: Array[Vector2i] = room["cells"]
	var average := Vector3.ZERO
	for cell: Vector2i in cells:
		average += _cell_world(cell, center)
	average /= maxf(1.0, float(cells.size()))
	average.y = float(room.get("elevation", 0.0)) + 1.25
	var label := Label3D.new()
	label.name = "RoomLabel_%s" % str(room.get("id", "room"))
	var visited := bool(room.get("visited", true))
	var completed := bool(room.get("completed", false))
	var is_current := bool(room.get("is_current", false))
	var room_name := str(room.get("name", room.get("id", "房间")))
	if not visited:
		label.text = "? 未到访 · %d格" % int(room.get("size", 1))
		label.modulate = Color("a9bac0")
	elif is_current:
		label.text = "%s · 当前" % room_name
		label.modulate = Color("f3b52b")
	elif completed:
		label.text = "%s · 已完成" % room_name
		label.modulate = Color("78c9ad")
	else:
		label.text = "%s · 已到访" % room_name
		label.modulate = Color("d5ddd8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 44
	label.outline_size = 10
	label.pixel_size = 0.007
	_add_to_visual_root(label, room_index, average)


func room_state_counts() -> Dictionary:
	var result := {"unvisited": 0, "visited": 0, "completed": 0, "current": 0}
	for room: Dictionary in rooms:
		if bool(room.get("is_current", false)):
			result["current"] = int(result["current"]) + 1
		if bool(room.get("completed", false)):
			result["completed"] = int(result["completed"]) + 1
		elif bool(room.get("visited", true)):
			result["visited"] = int(result["visited"]) + 1
		else:
			result["unvisited"] = int(result["unvisited"]) + 1
	return result


func room_state_debug_summary() -> String:
	var counts := room_state_counts()
	return "房态 未到%d · 已到%d · 完成%d · 当前%d" % [int(counts["unvisited"]), int(counts["visited"]), int(counts["completed"]), int(counts["current"])]


func room_state_visual_is_consistent() -> bool:
	if room_visual_roots.size() != rooms.size():
		return false
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var root: Node3D = room_visual_roots[room_index]
		var cover_count := root.find_children("UnvisitedCover_*", "MeshInstance3D", true, false).size()
		var expected_cover_count := 0 if bool(room.get("visited", true)) else int(room.get("size", 0))
		if cover_count != expected_cover_count:
			return false
		var props := root.find_children("RoomProp_%02d_*" % room_index, "Node3D", true, false)
		var expected_props := 0
		for record: Dictionary in prop_placement_records:
			if int(record.get("room_index", -1)) == room_index:
				expected_props += 1
		if props.size() != expected_props:
			return false
		if not bool(room.get("visited", true)) and expected_props != 0:
			return false
	return true


func prop_layout_fingerprint() -> String:
	var parts: Array[String] = []
	for record: Dictionary in prop_placement_records:
		var position: Vector3 = record["position"]
		parts.append("%s:%s:%s:%.3f,%.3f:%.3f" % [str(record["room_id"]), str(record["asset_id"]), str(record["slot"]), position.x, position.z, float(record["yaw"])])
	return ";".join(parts)


func room_prop_layout_fingerprint(room_id: String) -> String:
	var parts: Array[String] = []
	for record: Dictionary in prop_placement_records:
		if str(record.get("room_id", "")) != room_id:
			continue
		var position: Vector3 = record["position"]
		parts.append("%s:%s:%.3f,%.3f:%.3f" % [str(record["asset_id"]), str(record["slot"]), position.x, position.z, float(record["yaw"])])
	return ";".join(parts)


func prop_layout_is_valid() -> bool:
	return prop_placement_issues.is_empty() and prop_count == prop_placement_records.size()


func interaction_slots_are_valid() -> bool:
	if not interaction_slot_issues.is_empty():
		return false
	var expected_total := 0
	for room_index in range(rooms.size()):
		var room: Dictionary = rooms[room_index]
		var expected_per_cell := 4 if bool(room.get("visited", true)) else 0
		for cell: Vector2i in room["cells"]:
			expected_total += expected_per_cell
			var slots := interaction_slots_for_cell(cell)
			if slots.size() != expected_per_cell:
				return false
			for slot_index in range(slots.size()):
				if slots[slot_index].get("cell", Vector2i.ZERO) != cell or int(slots[slot_index].get("slot_index", -1)) != slot_index:
					return false
	return interaction_slot_records.size() == expected_total


func show_evidence_is_valid() -> bool:
	if not show_evidence_issues.is_empty():
		return false
	var visited_room_count := 0
	for room: Dictionary in rooms:
		if bool(room.get("visited", true)):
			visited_room_count += 1
	if show_evidence_records.size() != visited_room_count:
		return false
	for record: Dictionary in show_evidence_records:
		if str(record.get("kind", "")) != "actor_mark" or bool(record.get("affects_topology", true)):
			return false
		var room_index := int(record.get("room_index", -1))
		var matched_slot := false
		for slot: Dictionary in interaction_slots_for_room_index(room_index):
			if slot.get("cell", Vector2i.ZERO) != record.get("cell", Vector2i.ZERO):
				continue
			if int(slot.get("slot_index", -1)) != int(record.get("slot_index", -2)):
				continue
			if not (slot.get("position", Vector3.INF) as Vector3).is_equal_approx(record.get("position", Vector3.ZERO)):
				continue
			matched_slot = true
			break
		if not matched_slot or generated_root.find_child(str(record.get("node_name", "")), true, false) == null:
			return false
	return true


func production_fixtures_are_valid() -> bool:
	if not production_fixture_issues.is_empty():
		return false
	var visited_room_count := 0
	for room: Dictionary in rooms:
		if bool(room.get("visited", true)):
			visited_room_count += 1
	if production_fixture_records.size() != visited_room_count:
		return false
	for record: Dictionary in production_fixture_records:
		if str(record.get("kind", "")) not in ["cue_card", "fake_window", "on_air"] or bool(record.get("affects_topology", true)):
			return false
		var theme := str(record.get("theme", ""))
		var anomaly_id := str(record.get("anomaly_id", ""))
		if anomaly_id.is_empty() or anomaly_id != RoomPropCatalog.anomaly_for_theme(theme):
			return false
		var edge_key := str(record.get("edge_key", ""))
		var edge_record: Dictionary = visual_edge_records.get(edge_key, {})
		if str(edge_record.get("kind", "")) not in ["outer", "divider", "door"] or bool(edge_record.get("passage_open", false)):
			return false
		var room_index := int(record.get("room_index", -1))
		if room_index < 0 or room_index >= room_visual_roots.size():
			return false
		var fixture := room_visual_roots[room_index].find_child(str(record.get("node_name", "")), true, false) as Node3D
		if fixture == null or not (fixture in wall_bound_prop_nodes.get(edge_key, [])):
			return false
		var anomaly_cue := fixture.get_node_or_null("AnomalyCue") as Node3D
		if anomaly_cue == null or str(anomaly_cue.get_meta("anomaly_id", "")) != anomaly_id:
			return false
	return true


func theme_anomalies_are_valid() -> bool:
	if RoomPropCatalog.THEME_ANOMALIES.size() != RoomPropCatalog.THEMES.size():
		return false
	var anomaly_ids: Array[String] = []
	for theme: String in RoomPropCatalog.THEMES:
		var anomaly_id := RoomPropCatalog.anomaly_for_theme(theme)
		if anomaly_id.is_empty() or anomaly_id in anomaly_ids:
			return false
		anomaly_ids.append(anomaly_id)
	for record: Dictionary in production_fixture_records:
		if str(record.get("anomaly_id", "")) != RoomPropCatalog.anomaly_for_theme(str(record.get("theme", ""))):
			return false
	return true


func production_fixture_debug_summary() -> String:
	var parts: Array[String] = ["records=%d issues=%s" % [production_fixture_records.size(), str(production_fixture_issues)]]
	for record: Dictionary in production_fixture_records:
		var room_index := int(record.get("room_index", -1))
		var edge_key := str(record.get("edge_key", ""))
		var node_name := str(record.get("node_name", ""))
		var fixture: Node3D = null
		if room_index >= 0 and room_index < room_visual_roots.size():
			fixture = room_visual_roots[room_index].find_child(node_name, true, false) as Node3D
		var is_bound: bool = fixture != null and fixture in wall_bound_prop_nodes.get(edge_key, [])
		parts.append("r%d:%s edge=%s node=%s bound=%s" % [room_index, str(record.get("kind", "")), edge_key, str(fixture != null), str(is_bound)])
	return " | ".join(parts)


func set_room_broadcast_glitch(room_index: int, active: bool) -> bool:
	if room_index < 0 or room_index >= room_visual_roots.size() or not bool(rooms[room_index].get("visited", true)):
		return false
	room_broadcast_states[room_index] = active
	var room_root: Node3D = room_visual_roots[room_index]
	room_root.set_meta("broadcast_glitch", active)
	for raw_fixture: Node in room_root.find_children("ProductionFixture_*", "Node3D", true, false):
		var fixture := raw_fixture as Node3D
		fixture.rotation.z = -0.10 if active else 0.0
		fixture.scale = Vector3.ONE * (1.10 if active else 1.0)
		var anomaly_cue := fixture.get_node_or_null("AnomalyCue") as Node3D
		if anomaly_cue != null:
			anomaly_cue.visible = active
		_set_node_emission(fixture, active, Color("ff4d8d"))
	for raw_mark: Node in room_root.find_children("ShowEvidence_*", "Node3D", true, false):
		var mark := raw_mark as Node3D
		mark.scale = Vector3.ONE * (1.18 if active else 1.0)
		_set_node_emission(mark, active, Color("f7df5c"))
	return true


func _set_node_emission(root: Node3D, active: bool, color: Color) -> void:
	for raw_mesh: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := raw_mesh as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		material.emission_enabled = active
		material.emission = color
		material.emission_energy_multiplier = 0.72 if active else 0.0


func room_broadcast_glitch_is_applied(room_index: int, expected: bool) -> bool:
	if room_index < 0 or room_index >= room_visual_roots.size():
		return false
	var room_root: Node3D = room_visual_roots[room_index]
	if bool(room_root.get_meta("broadcast_glitch", false)) != expected or bool(room_broadcast_states.get(room_index, false)) != expected:
		return false
	var fixtures := room_root.find_children("ProductionFixture_*", "Node3D", true, false)
	var marks := room_root.find_children("ShowEvidence_*", "Node3D", true, false)
	if bool(rooms[room_index].get("visited", true)) and (fixtures.size() != 1 or marks.size() != 1):
		return false
	for raw_fixture: Node in fixtures:
		var fixture := raw_fixture as Node3D
		if not is_equal_approx(fixture.rotation.z, -0.10 if expected else 0.0):
			return false
		var anomaly_cue := fixture.get_node_or_null("AnomalyCue") as Node3D
		if anomaly_cue == null or anomaly_cue.visible != expected:
			return false
	for raw_mark: Node in marks:
		var mark := raw_mark as Node3D
		if not is_equal_approx(mark.scale.x, 1.18 if expected else 1.0):
			return false
	return true


func toy_show_shell_palette_is_applied() -> bool:
	if not use_toy_show_shell_palette:
		return true
	if use_toy_show_cardboard_shell:
		return cardboard_shell_is_valid()
	if toy_show_shell_nodes.is_empty():
		return false
	for model: Node3D in toy_show_shell_nodes:
		if not is_instance_valid(model) or not bool(model.get_meta("toy_show_shell_material", false)):
			return false
		var mesh_count := 0
		if model is MeshInstance3D:
			mesh_count += 1
			if (model as MeshInstance3D).material_override == null:
				return false
		for child: Node in model.find_children("*", "MeshInstance3D", true, false):
			mesh_count += 1
			if (child as MeshInstance3D).material_override == null:
				return false
		if mesh_count == 0:
			return false
	return true


func cardboard_shell_is_valid() -> bool:
	if not use_toy_show_cardboard_shell:
		return true
	var expected_structural_records := visual_edge_records.size() - open_passage_count
	var structural_records := 0
	var junction_records := 0
	for record: Dictionary in cardboard_shell_records:
		var kind := str(record.get("kind", ""))
		if kind == "junction":
			junction_records += 1
			if not is_equal_approx(float(record.get("width", 0.0)), KAYKIT_JUNCTION_WIDTH):
				return false
			continue
		structural_records += 1
		if not kind in ["outer", "divider", "door"]:
			return false
		if not is_equal_approx(float(record.get("span", 0.0)) + KAYKIT_JUNCTION_WIDTH, CELL):
			return false
		if kind == "door" and not is_equal_approx(float(record.get("opening", 0.0)), CARDBOARD_DOOR_OPENING):
			return false
		var edge_key := str(record.get("edge_key", ""))
		var node := structural_edge_nodes.get(edge_key) as Node3D
		if node == null or not bool(node.get_meta("cardboard_shell", false)):
			return false
	return structural_records == expected_structural_records and junction_records == junction_count


func interaction_slots_for_room_index(room_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in interaction_slot_records:
		if int(slot.get("room_index", -1)) == room_index:
			result.append(slot)
	result.sort_custom(_interaction_slot_less)
	return result


func interaction_slots_for_cell(cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in interaction_slot_records:
		if slot.get("cell", Vector2i.ZERO) == cell:
			result.append(slot)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0)))
	return result


func _interaction_slot_less(a: Dictionary, b: Dictionary) -> bool:
	var cell_a: Vector2i = a.get("cell", Vector2i.ZERO)
	var cell_b: Vector2i = b.get("cell", Vector2i.ZERO)
	if cell_a.y != cell_b.y:
		return cell_a.y < cell_b.y
	if cell_a.x != cell_b.x:
		return cell_a.x < cell_b.x
	return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))


func interaction_slot_for_cell(cell: Vector2i, actor_index: int = 0) -> Dictionary:
	var slots := interaction_slots_for_cell(cell)
	if slots.is_empty():
		return {}
	return slots[posmod(actor_index, slots.size())].duplicate(true)


func prop_counts_match_room_sizes() -> bool:
	for room_index in range(rooms.size()):
		var count := 0
		for record: Dictionary in prop_placement_records:
			if int(record.get("room_index", -1)) == room_index:
				count += 1
		if not bool(rooms[room_index].get("visited", true)):
			if count != 0:
				return false
			continue
		var allowed := RoomPropCatalog.count_range_for_size(int(rooms[room_index].get("size", 1)))
		if count < allowed.x or count > allowed.y:
			return false
	return true


func prop_records_match_themes() -> bool:
	for record: Dictionary in prop_placement_records:
		var matching := false
		for entry: Dictionary in RoomPropCatalog.entries_for(str(record.get("theme", "")), str(record.get("slot", ""))):
			if str(entry.get("id", "")) == str(record.get("asset_id", "")):
				matching = true
				break
		if not matching:
			return false
	return true


func props_use_handmade_finishes() -> bool:
	return handmade_finish_debug_summary() == "ok"


func handmade_finish_debug_summary() -> String:
	if prop_placement_records.is_empty():
		return "no prop records"
	for record: Dictionary in prop_placement_records:
		var finish := str(record.get("handmade_finish", ""))
		if finish not in ["felt", "painted_wood", "clay"]:
			return "%s invalid finish %s" % [str(record.get("asset_id", "")), finish]
		if finish != RoomPropCatalog.handmade_finish_for(str(record.get("asset_id", ""))):
			return "%s catalog finish mismatch" % str(record.get("asset_id", ""))
		var room_index := int(record.get("room_index", -1))
		if room_index < 0 or room_index >= room_visual_roots.size():
			return "%s invalid room %d" % [str(record.get("asset_id", "")), room_index]
		var prop := room_visual_roots[room_index].find_child(str(record.get("node_name", "")), true, false) as Node3D
		if prop == null or str(prop.get_meta("handmade_finish", "")) != finish:
			return "%s prop node or metadata missing (%s)" % [str(record.get("asset_id", "")), str(record.get("node_name", ""))]
		var expected_surfaces := int(record.get("finish_surface_count", 0))
		if expected_surfaces <= 0 or int(prop.get_meta("handmade_finish_surface_count", 0)) != expected_surfaces:
			return "%s surface metadata mismatch expected=%d actual=%d" % [str(record.get("asset_id", "")), expected_surfaces, int(prop.get_meta("handmade_finish_surface_count", 0))]
		var validated_surfaces := 0
		for mesh_instance: MeshInstance3D in _mesh_instances_in(prop):
			if mesh_instance.mesh == null:
				continue
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
				if material == null:
					return "%s surface %d missing override" % [str(record.get("asset_id", "")), surface_index]
				if material.roughness + 0.0001 < _handmade_finish_roughness(finish) or material.metallic > 0.05:
					return "%s surface %d material r=%.3f m=%.3f" % [str(record.get("asset_id", "")), surface_index, material.roughness, material.metallic]
				validated_surfaces += 1
		if validated_surfaces != expected_surfaces:
			return "%s validated surface mismatch expected=%d actual=%d" % [str(record.get("asset_id", "")), expected_surfaces, validated_surfaces]
	return "ok"


func prop_compositions_are_coherent() -> bool:
	for room_index in range(rooms.size()):
		if not bool(rooms[room_index].get("visited", true)):
			continue
		var room_records: Array[Dictionary] = []
		for record: Dictionary in prop_placement_records:
			if int(record.get("room_index", -1)) == room_index:
				room_records.append(record)
		if room_records.is_empty():
			return false
		var composition_id := str(room_records[0].get("composition_id", ""))
		if composition_id.is_empty() or composition_id == "fallback":
			return false
		var matched := 0
		for record: Dictionary in room_records:
			if str(record.get("composition_id", "")) != composition_id:
				return false
			if bool(record.get("composition_matched", false)):
				matched += 1
		# Door-heavy single cells may have no legal second wall anchor. Preserve the
		# composition's visual subject, then prefer clearance over forced matching.
		if matched < 1:
			return false
	return true


func prop_placements_respect_reserved_clearance() -> bool:
	for record: Dictionary in prop_placement_records:
		var room_index := int(record.get("room_index", -1))
		var position: Vector3 = record["position"]
		var footprint: Vector2 = record["footprint"]
		var radius := maxf(footprint.x, footprint.y) * 0.5
		for raw_edge: Variant in visual_edge_records.values():
			var edge_record: Dictionary = raw_edge
			if str(edge_record.get("kind", "")) != "door":
				continue
			var edge_cell: Vector2i = edge_record["cell"]
			var edge_neighbor: Vector2i = edge_record["neighbor"]
			if int(occupancy.get(edge_cell, -2)) != room_index and int(occupancy.get(edge_neighbor, -2)) != room_index:
				continue
			var midpoint := (_cell_world(edge_cell, layout_center) + _cell_world(edge_neighbor, layout_center)) * 0.5
			if Vector2(position.x - midpoint.x, position.z - midpoint.z).length() < radius + 0.30:
				return false
	return true


func prop_assets_and_licenses_are_available() -> bool:
	for path: String in RoomPropCatalog.asset_paths():
		if not ResourceLoader.exists(path):
			return false
	var distribution := RoomPropCatalog.kaykit_distribution_paths()
	if distribution.size() != 53:
		return false
	for path: String in distribution:
		if load(path) as PackedScene == null:
			return false
	for path: String in RoomPropCatalog.license_paths():
		if not FileAccess.file_exists(path):
			return false
	return true


func wall_bound_props_match_cutaway() -> bool:
	for raw_key: Variant in wall_bound_prop_nodes.keys():
		var expected_visible := not cutaway_culled_edge_keys.has(str(raw_key))
		for prop: Node3D in wall_bound_prop_nodes[raw_key]:
			if not is_instance_valid(prop) or prop.visible != expected_visible:
				return false
	return true


func shared_prop_catalog_entries() -> Array:
	return RoomPropCatalog.ENTRIES.duplicate(true)


func room_prop_placement_request(room_index: int) -> Dictionary:
	if room_index < 0 or room_index >= rooms.size():
		return {}
	return RoomPropCatalog.placement_request(rooms[room_index], room_index, generation_seed)


func _build_title(size: Vector2i) -> void:
	var label := Label3D.new()
	label.name = "GenerationSummary"
	label.position = Vector3(0, 3.15, -layout_extent * 0.22)
	label.text = "SEED %d · %d 房 / %d 格\n1→5 首组验证 · 同房去内墙 · 跨房门洞" % [generation_seed, rooms.size(), occupancy.size()]
	label.modulate = Color("ffe3a3")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 50
	label.outline_size = 12
	label.pixel_size = 0.008
	generated_root.add_child(label)


func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color, room_index: int = -1) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_add_to_visual_root(mesh_instance, room_index, position)


func _add_model(node_name: String, path: String, position: Vector3, scale_value: Vector3, yaw: float, room_index: int = -1) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("PCG diorama asset missing: %s" % path)
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	model.name = node_name
	model.scale = scale_value
	model.rotation.y = yaw
	_add_to_visual_root(model, room_index, position)
	if use_toy_show_shell_palette and path.begins_with(KAYKIT_ROOT) and (node_name.contains("Wall") or node_name.begins_with("Doorway") or node_name.begins_with("Junction")):
		_apply_toy_show_shell_material(model, node_name, room_index)
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return model


func _apply_handmade_prop_finish(model: Node3D, asset_id: String, finish: String) -> int:
	var tint := RoomPropCatalog.handmade_tint_for(asset_id)
	var tint_strength := 0.30 if finish == "felt" else (0.20 if finish == "painted_wood" else 0.24)
	var surface_count := 0
	for mesh_instance: MeshInstance3D in _mesh_instances_in(model):
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_surface_override_material(surface_index)
			if source_material == null:
				source_material = mesh_instance.mesh.surface_get_material(surface_index)
			var material: StandardMaterial3D
			if source_material is StandardMaterial3D:
				material = source_material.duplicate() as StandardMaterial3D
			else:
				material = StandardMaterial3D.new()
			var source_color := material.albedo_color
			var target_color := tint
			target_color.a = source_color.a
			material.albedo_color = source_color.lerp(target_color, tint_strength)
			material.roughness = maxf(material.roughness, _handmade_finish_roughness(finish))
			material.metallic = minf(material.metallic, 0.03)
			mesh_instance.set_surface_override_material(surface_index, material)
			surface_count += 1
	model.set_meta("handmade_finish", finish)
	model.set_meta("handmade_finish_surface_count", surface_count)
	return surface_count


func _handmade_finish_roughness(finish: String) -> float:
	match finish:
		"felt":
			return 0.98
		"painted_wood":
			return 0.90
		_:
			return 0.95


func _mesh_instances_in(root: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result


func _add_cardboard_wall(node_name: String, position: Vector3, yaw: float, room_index: int, edge_key: String, edge_kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.rotation.y = yaw
	var span := CELL - KAYKIT_JUNCTION_WIDTH
	var base_color := _toy_show_shell_color(room_index)
	_add_cardboard_box(root, "Panel", Vector3(0, KAYKIT_WALL_HEIGHT * 0.5, 0), Vector3(span, KAYKIT_WALL_HEIGHT, CARDBOARD_PANEL_THICKNESS), base_color)
	_add_cardboard_box(root, "TopFold", Vector3(0, KAYKIT_WALL_HEIGHT + 0.025, 0), Vector3(span + 0.04, 0.05, CARDBOARD_PANEL_THICKNESS + 0.035), base_color.lightened(0.10))
	var seam_x := (float(posmod(node_name.hash(), 3)) - 1.0) * span * 0.27
	_add_cardboard_box(root, "TapeSeam", Vector3(seam_x, KAYKIT_WALL_HEIGHT * 0.54, -CARDBOARD_PANEL_THICKNESS * 0.54), Vector3(0.045, KAYKIT_WALL_HEIGHT * 0.76, 0.012), Color("e5d49d"), false)
	for raw_sign: Variant in [-1.0, 1.0]:
		var sign_value := float(raw_sign)
		_add_cardboard_box(root, "BackFoot_%s" % str(sign_value), Vector3(span * 0.34 * sign_value, 0.055, -0.14), Vector3(0.07, 0.11, 0.34), base_color.darkened(0.14))
	root.set_meta("cardboard_shell", true)
	_add_to_visual_root(root, room_index, position)
	toy_show_shell_nodes.append(root)
	cardboard_shell_records.append({"kind": edge_kind, "edge_key": edge_key, "span": span, "node_name": node_name})
	return root


func _add_cardboard_doorway(node_name: String, position: Vector3, yaw: float, room_index: int, edge_key: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.rotation.y = yaw
	var span := CELL - KAYKIT_JUNCTION_WIDTH
	var side_width := (span - CARDBOARD_DOOR_OPENING) * 0.5
	var door_height := KAYKIT_WALL_HEIGHT * 0.72
	var base_color := _toy_show_shell_color(room_index).lightened(0.06)
	for raw_sign: Variant in [-1.0, 1.0]:
		var sign_value := float(raw_sign)
		var side_x := (CARDBOARD_DOOR_OPENING * 0.5 + side_width * 0.5) * sign_value
		_add_cardboard_box(root, "Side_%s" % str(sign_value), Vector3(side_x, KAYKIT_WALL_HEIGHT * 0.5, 0), Vector3(side_width, KAYKIT_WALL_HEIGHT, CARDBOARD_PANEL_THICKNESS), base_color)
	var header_height := KAYKIT_WALL_HEIGHT - door_height
	_add_cardboard_box(root, "Header", Vector3(0, door_height + header_height * 0.5, 0), Vector3(CARDBOARD_DOOR_OPENING, header_height, CARDBOARD_PANEL_THICKNESS), base_color)
	_add_cardboard_box(root, "TopFold", Vector3(0, KAYKIT_WALL_HEIGHT + 0.025, 0), Vector3(span + 0.04, 0.05, CARDBOARD_PANEL_THICKNESS + 0.035), base_color.lightened(0.10))
	var door_color := _toy_show_shell_color(room_index).darkened(0.12)
	_add_cardboard_box(root, "DoorLeaf", Vector3(0, door_height * 0.47, -0.012), Vector3(CARDBOARD_DOOR_OPENING * 0.86, door_height * 0.90, 0.045), door_color)
	_add_cardboard_box(root, "DoorCue", Vector3(CARDBOARD_DOOR_OPENING * 0.24, door_height * 0.48, -0.04), Vector3(0.045, 0.045, 0.035), Color("f1c24b"), false)
	root.set_meta("cardboard_shell", true)
	_add_to_visual_root(root, room_index, position)
	toy_show_shell_nodes.append(root)
	cardboard_shell_records.append({"kind": "door", "edge_key": edge_key, "span": span, "opening": CARDBOARD_DOOR_OPENING, "node_name": node_name})
	return root


func _add_cardboard_junction(node_name: String, position: Vector3, height: float, room_index: int, edge_keys: Array) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	var base_color := _toy_show_shell_color(room_index).darkened(0.10)
	_add_cardboard_box(root, "Post", Vector3(0, height * 0.5, 0), Vector3(KAYKIT_JUNCTION_WIDTH, height, KAYKIT_JUNCTION_WIDTH), base_color)
	_add_cardboard_box(root, "PostCap", Vector3(0, height + 0.025, 0), Vector3(KAYKIT_JUNCTION_WIDTH + 0.035, 0.05, KAYKIT_JUNCTION_WIDTH + 0.035), base_color.lightened(0.10))
	_add_cardboard_box(root, "TapeBand", Vector3(0, height * 0.68, 0), Vector3(KAYKIT_JUNCTION_WIDTH + 0.012, 0.045, KAYKIT_JUNCTION_WIDTH + 0.012), Color("e5d49d"), false)
	root.set_meta("cardboard_shell", true)
	_add_to_visual_root(root, room_index, position)
	toy_show_shell_nodes.append(root)
	cardboard_shell_records.append({"kind": "junction", "edge_keys": edge_keys, "width": KAYKIT_JUNCTION_WIDTH, "node_name": node_name})
	return root


func _add_cardboard_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, color: Color, cast_shadow := true) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.98
	material.metallic = 0.0
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _toy_show_shell_color(room_index: int) -> Color:
	var palette := [
		Color("d6afa5"),
		Color("9fb9ad"),
		Color("b9acd0"),
		Color("d2c27d"),
		Color("9eb8c7"),
		Color("d3b89b"),
	]
	return palette[posmod(room_index, palette.size())]


func _apply_toy_show_shell_material(model: Node3D, node_name: String, room_index: int) -> void:
	var color := _toy_show_shell_color(room_index)
	if node_name.begins_with("Doorway"):
		color = color.lightened(0.08)
	elif node_name.begins_with("Junction"):
		color = color.darkened(0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.97
	material.metallic = 0.0
	if model is MeshInstance3D:
		(model as MeshInstance3D).material_override = material
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material
	model.set_meta("toy_show_shell_material", true)
	toy_show_shell_nodes.append(model)


func _add_to_visual_root(node: Node3D, room_index: int, world_position: Vector3) -> void:
	if room_index >= 0 and room_index < room_visual_roots.size():
		var room_root: Node3D = room_visual_roots[room_index]
		node.position = world_position - room_root.position
		room_root.add_child(node)
	else:
		node.position = world_position
		generated_root.add_child(node)


func _play_room_build_animation() -> void:
	if room_visual_roots.is_empty() or not is_inside_tree():
		return
	if build_tween != null and build_tween.is_valid():
		build_tween.kill()
	for room_root: Node3D in room_visual_roots:
		room_root.visible = false
		room_root.scale = Vector3.ONE * 0.78
		room_root.rotation = Vector3(deg_to_rad(-18.0), 0.0, 0.0)
		room_root.position.y = 3.2
	build_tween = create_tween()
	for room_root: Node3D in room_visual_roots:
		build_tween.tween_callback(room_root.set_visible.bind(true))
		build_tween.set_parallel(true)
		build_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		build_tween.tween_property(room_root, "position:y", 0.0, room_drop_duration)
		build_tween.tween_property(room_root, "rotation", Vector3.ZERO, room_drop_duration)
		build_tween.tween_property(room_root, "scale", Vector3.ONE * 1.035, room_drop_duration)
		build_tween.set_parallel(false)
		build_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		build_tween.tween_property(room_root, "scale", Vector3.ONE, 0.08)
		if room_drop_gap > 0.0:
			build_tween.tween_interval(room_drop_gap)


func _cell_world(cell: Vector2i, center: Vector2) -> Vector3:
	return Vector3((float(cell.x) - center.x) * CELL, 0.0, (float(cell.y) - center.y) * CELL)


func _cell_bounds() -> Dictionary:
	var first: Vector2i = occupancy.keys()[0]
	var minimum := first
	var maximum := first
	for raw_cell: Variant in occupancy.keys():
		var cell: Vector2i = raw_cell
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return {"min": minimum, "max": maximum}


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a if _cell_precedes(a, b) else b
	var second := b if first == a else a
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]


func _cell_precedes(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


func _direction_yaw(direction: Vector2i) -> float:
	if direction == Vector2i.RIGHT:
		return -PI * 0.5
	if direction == Vector2i.LEFT:
		return PI * 0.5
	if direction == Vector2i.DOWN:
		return PI
	return 0.0


func _apply_standalone_camera() -> void:
	var target := camera_target()
	standalone_camera.position = target + Vector3(0, layout_extent * 0.45 + 3.0, layout_extent * 0.70 + 4.0)
	standalone_camera.look_at(target, Vector3.UP)


func camera_target() -> Vector3:
	return Vector3(0.0, 0.75, 0.0)


func suggested_camera_distance() -> float:
	return clampf(layout_extent * 0.90 + 5.0, 14.0, 24.0)


func generation_fingerprint() -> String:
	var cells: Array = occupancy.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_precedes(a, b))
	var parts: Array[String] = []
	for cell: Vector2i in cells:
		parts.append("%d,%d:%d" % [cell.x, cell.y, int(occupancy[cell])])
	return ";".join(parts)


func shell_geometry_is_grid_exact() -> bool:
	if not visual_geometry_issues.is_empty():
		return false
	var floor_span := 4.0 * KAYKIT_FLOOR_SCALE.x
	var wall_span := 4.0 * KAYKIT_WALL_SCALE.x + KAYKIT_JUNCTION_WIDTH
	var door_span := 4.0 * KAYKIT_DOOR_SCALE.x + KAYKIT_JUNCTION_WIDTH
	var junction_span := 1.5 * (KAYKIT_JUNCTION_WIDTH / 1.5)
	return is_equal_approx(floor_span, CELL) and is_equal_approx(wall_span, CELL) and is_equal_approx(door_span, CELL) and is_equal_approx(junction_span, KAYKIT_JUNCTION_WIDTH)


func layout_quality_metrics() -> Dictionary:
	if occupancy.is_empty():
		return {"width": 0, "height": 0, "aspect_delta": 0, "holes": 0, "compactness": 0.0}
	var bounds := _cell_bounds()
	var minimum: Vector2i = bounds["min"]
	var maximum: Vector2i = bounds["max"]
	var width := maximum.x - minimum.x + 1
	var height := maximum.y - minimum.y + 1
	var holes := 0
	for y in range(minimum.y + 1, maximum.y):
		for x in range(minimum.x + 1, maximum.x):
			var cell := Vector2i(x, y)
			if occupancy.has(cell):
				continue
			var surrounded := true
			for direction: Vector2i in DIRS:
				if not occupancy.has(cell + direction):
					surrounded = false
					break
			if surrounded:
				holes += 1
	return {"width": width, "height": height, "aspect_delta": absi(width - height), "holes": holes, "compactness": float(occupancy.size()) / float(maxi(1, width * height))}
