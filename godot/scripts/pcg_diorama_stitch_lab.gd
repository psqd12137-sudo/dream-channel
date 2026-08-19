@tool
extends Node3D

const RoomFootprintCatalog = preload("res://scripts/room_footprint_catalog.gd")

const KENNEY_ROOT := "res://assets/third_party/kenney_mini_dungeon/models/"
const KAYKIT_ROOT := "res://assets/third_party/kaykit_dungeon/models/"
const RUINS_ROOT := "res://assets/third_party/quaternius_ultimate_modular_ruins/models/"
const CELL := 1.55
const ELEVATION_STEP := 0.58
const KAYKIT_WALL_HEIGHT := 1.08
const KAYKIT_JUNCTION_WIDTH := 0.28
const KAYKIT_FLOOR_SCALE := Vector3.ONE * (CELL / 4.0)
const KAYKIT_WALL_SCALE := Vector3((CELL - KAYKIT_JUNCTION_WIDTH) / 4.0, KAYKIT_WALL_HEIGHT / 4.0, KAYKIT_JUNCTION_WIDTH)
const KAYKIT_DOOR_SCALE := Vector3((CELL - KAYKIT_JUNCTION_WIDTH) / 4.0, KAYKIT_WALL_HEIGHT / 4.0, KAYKIT_JUNCTION_WIDTH)
const KAYKIT_STAIR_SCALE := Vector3(CELL / 3.3, ELEVATION_STEP / 4.05, CELL / 6.0)
const KAYKIT_PROP_SCALE := 0.28
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SHAPE_SEQUENCE := ["single", "plus5", "l3", "single", "line3", "single", "l3", "single", "t5", "single"]
const PROP_ASSETS := [
	KAYKIT_ROOT + "table_small.gltf.glb",
	KAYKIT_ROOT + "barrel_large.gltf.glb",
	KAYKIT_ROOT + "candle_lit.gltf.glb",
]

@export var generation_seed := 20260816
@export_range(6, 16, 1) var room_target := 10
@export var show_room_ids := true
@export var animate_room_build := true
@export var kenney_only := true
@export var use_kaykit_room_shell := true
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
var stair_count := 0
var prop_count := 0
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
var cutaway_focus_room_index := -1
var layout_extent := 8.0

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
	stair_count = 0
	prop_count = 0
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
	var floor_asset := KAYKIT_ROOT + ("floor_wood_large_dark.gltf.glb" if use_kaykit_room_shell and posmod(cell.x * 17 + cell.y * 31 + generation_seed, 7) == 0 else "floor_wood_large.gltf.glb") if use_kaykit_room_shell else KENNEY_ROOT + ("floor-detail.fbx" if posmod(cell.x * 17 + cell.y * 31 + generation_seed, 7) == 0 else "floor.fbx")
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
					_spawn_connection(cell, neighbor, side, center)
					_record_visual_edge(edge_key, "door", cell, neighbor)
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


func _spawn_connection(cell: Vector2i, neighbor: Vector2i, side: int, center: Vector2) -> void:
	var elevation_a := float(rooms[int(occupancy[cell])].get("elevation", 0.0))
	var elevation_b := float(rooms[int(occupancy[neighbor])].get("elevation", 0.0))
	var low_elevation := minf(elevation_a, elevation_b)
	var direction: Vector2i = DIRS[side]
	var position := _cell_world(cell, center) + Vector3(float(direction.x) * CELL * 0.5, low_elevation + 0.02, float(direction.y) * CELL * 0.5)
	var yaw := PI * 0.5 if side in [1, 3] else 0.0
	var connection_room_index := maxi(int(occupancy[cell]), int(occupancy[neighbor]))
	var doorway_model: Node3D = null
	if use_kaykit_room_shell:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KAYKIT_ROOT + "wall_doorway.glb", position, KAYKIT_DOOR_SCALE, _direction_yaw(direction), connection_room_index)
	elif kenney_only:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KENNEY_ROOT + "wall-opening.fbx", _cell_world(cell, center) + Vector3(0, elevation_a + 0.025, 0), Vector3.ONE * CELL, _direction_yaw(direction), connection_room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * CELL, _direction_yaw(direction), connection_room_index)
	else:
		doorway_model = _add_model("Doorway_%d" % doorway_count, RUINS_ROOT + "Arch_Round.fbx", position, Vector3(CELL / 3.1, 0.38, 0.55), yaw, connection_room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * 1.12, yaw, connection_room_index)
	_tag_structural_edge(doorway_model, _edge_key(cell, neighbor), "door", cell, neighbor, direction)
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
	if use_kaykit_room_shell:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KAYKIT_ROOT + "wall_doorway.glb", position, KAYKIT_DOOR_SCALE, _direction_yaw(direction), room_index)
	elif kenney_only:
		doorway_model = _add_model("Doorway_%d" % doorway_count, KENNEY_ROOT + "wall-opening.fbx", _cell_world(cell, center) + Vector3(0, elevation + 0.025, 0), Vector3.ONE * CELL, _direction_yaw(direction), room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * CELL, _direction_yaw(direction), room_index)
	else:
		doorway_model = _add_model("Doorway_%d" % doorway_count, RUINS_ROOT + "Arch_Round.fbx", position, Vector3(CELL / 3.1, 0.38, 0.55), yaw, room_index)
		_add_model("Gate_%d" % doorway_count, KENNEY_ROOT + "gate.fbx", position + Vector3(0, 0.02, 0), Vector3.ONE * 1.12, yaw, room_index)
	_tag_structural_edge(doorway_model, _edge_key(cell, neighbor), "door", cell, neighbor, direction)
	doorway_count += 1

func _record_visual_edge(key: String, kind: String, cell: Vector2i, neighbor: Vector2i) -> void:
	if visual_edge_records.has(key):
		visual_geometry_issues.append("duplicate visual edge %s" % key)
		return
	visual_edge_records[key] = {"kind": kind, "cell": cell, "neighbor": neighbor}


func _tag_structural_edge(node: Node3D, edge_key: String, kind: String, cell: Vector2i, neighbor: Vector2i, direction: Vector2i) -> void:
	if node == null:
		return
	node.set_meta("structure_kind", kind)
	node.set_meta("edge_key", edge_key)
	node.set_meta("edge_cell", cell)
	node.set_meta("edge_neighbor", neighbor)
	node.set_meta("edge_direction", direction)
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
	cutaway_culled_edge_keys.clear()
	cutaway_culled_wall_count = 0
	cutaway_culled_doorway_count = 0
	cutaway_visible_wall_count = 0
	cutaway_visible_doorway_count = 0
	cutaway_focus_room_index = int(occupancy.get(focus_cell, -1))
	for raw_node: Variant in structural_edge_nodes.values():
		var edge_node := raw_node as Node3D
		if edge_node != null:
			edge_node.visible = true
	for raw_marker: Variant in cutaway_marker_nodes.values():
		var marker := raw_marker as Node3D
		if marker != null:
			marker.visible = false
	for junction: Node3D in structural_junction_nodes:
		if is_instance_valid(junction):
			junction.visible = true
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
		var should_cull := false
		if kind == "outer":
			should_cull = _edge_faces_camera(neighbor - cell, viewer_direction)
		elif kind == "door" and not occupancy.has(neighbor):
			should_cull = _edge_faces_camera(neighbor - cell, viewer_direction)
		elif kind in ["divider", "door"]:
			var outward := Vector2i.ZERO
			if int(occupancy.get(cell, -1)) == cutaway_focus_room_index:
				outward = neighbor - cell
			elif int(occupancy.get(neighbor, -1)) == cutaway_focus_room_index:
				outward = cell - neighbor
			if outward != Vector2i.ZERO:
				should_cull = _edge_faces_camera(outward, viewer_direction)
		var edge_node := structural_edge_nodes.get(edge_key) as Node3D
		if edge_node != null:
			edge_node.visible = not should_cull
		var cutaway_marker := cutaway_marker_nodes.get(edge_key) as Node3D
		if cutaway_marker != null:
			cutaway_marker.visible = should_cull
		if kind == "door":
			if should_cull:
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
	return cutaway_debug_state()


func _edge_faces_camera(outward: Vector2i, viewer_direction: Vector2) -> bool:
	var normal := Vector2(float(outward.x), float(outward.y)).normalized()
	return normal.dot(viewer_direction) > 0.35


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
		"edge_total": visual_edge_records.size(),
		"external_walls": external_wall_count,
		"divider_walls": divider_wall_count,
		"doorways": doorway_count,
	}


func cutaway_debug_summary() -> String:
	var state := cutaway_debug_state()
	return "PCG %d格房 · 剔除%d墙/%d门 · 可见%d墙/%d门 · 边%d=%d外+%d隔+%d门" % [
		int(state["focus_room_size"]),
		int(state["culled_walls"]),
		int(state["culled_doors"]),
		int(state["visible_walls"]),
		int(state["visible_doors"]),
		int(state["edge_total"]),
		int(state["external_walls"]),
		int(state["divider_walls"]),
		int(state["doorways"]),
	]


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
		var scale_value := Vector3(KAYKIT_JUNCTION_WIDTH / 1.5, height / 4.0, KAYKIT_JUNCTION_WIDTH / 1.5)
		var junction := _add_model("Junction_%s" % key, KAYKIT_ROOT + "pillar.gltf.glb", position, scale_value, 0.0, int(record["room_index"]))
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
		var cell: Vector2i = cells[posmod(room_index * 3 + generation_seed, cells.size())]
		var elevation := float(room.get("elevation", 0.0))
		var asset: String = PROP_ASSETS[posmod(room_index + generation_seed, PROP_ASSETS.size())]
		var world := _cell_world(cell, center) + Vector3(0, elevation + 0.06, 0)
		var prop_scale := KAYKIT_PROP_SCALE if use_kaykit_room_shell else (0.86 if int(room.get("size", 1)) == 1 else 0.95)
		_add_model("RoomProp_%02d" % room_index, asset, world, Vector3.ONE * prop_scale, float(posmod(room_index * 5, 8)) * PI * 0.25, room_index)
		prop_count += 1
		if show_room_ids:
			_add_room_label(room, room_index, center)


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
		var prop := root.find_child("RoomProp_%02d" % room_index, true, false)
		if bool(room.get("visited", true)) != (prop != null):
			return false
	return true


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
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return model


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
