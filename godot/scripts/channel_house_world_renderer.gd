class_name ChannelHouseWorldRenderer
extends RefCounted

## Runtime renderer for the formal house / exploration board.
## The host owns gameplay state; this module owns only house-world presentation.

const RoomRules = preload("res://scripts/room_rules.gd")
const CharacterPresenter = preload("res://scripts/character_presenter.gd")
const RoomArtRegistry = preload("res://scripts/room_art_registry.gd")
const PCG_HAND_LAYOUT_LAB = preload("res://scenes/pcg_hand_layout_lab.tscn")
const PCG_HAND_ROOM_SCRIPT = preload("res://scripts/pcg_hand_room.gd")
const KAYKIT_DUNGEON_ROOT := "res://assets/third_party/kaykit_dungeon/models/"

const HOUSE_CELL := 3.4
const VISUAL_CELL_SCALE := 1.20
const COL_PAPER := Color("f7e8c5")
const COL_TEAL := Color("23aa9b")
const COL_GOLD := Color("f2a51e")
const COL_MAGENTA := Color("d63b72")
const COL_GREEN := Color("66b66d")
const COL_RED := Color("d9574f")
const INVALID_CELL := Vector2i(-999, -999)

var host = null

var build_preview_tween:
	get: return host.build_preview_tween
	set(value): host.build_preview_tween = value
var house_root:
	get: return host.house_root
var room_rules:
	get: return host.room_rules
var kenney_build_lab_mode:
	get: return host.kenney_build_lab_mode
var phase:
	get: return host.phase
var selected_frontier:
	get: return host.selected_frontier
var build_offers:
	get: return host.build_offers
var selected_offer:
	get: return host.selected_offer
var offer_rotation:
	get: return host.offer_rotation
var hovered_house_cell:
	get: return host.hovered_house_cell
var current_room_pos:
	get: return host.current_room_pos
var house_player_facing_yaw:
	get: return host.house_player_facing_yaw
	set(value): host.house_player_facing_yaw = value
var house_actor_slot_assignments:
	get: return host.house_actor_slot_assignments
	set(value): host.house_actor_slot_assignments = value
var presentation:
	get: return host.presentation
var camera:
	get: return host.camera
var run_seed:
	get: return host.run_seed
var large_room_mix_test_mode:
	get: return host.large_room_mix_test_mode

func _init(next_host) -> void:
	host = next_host


func _clear_children(parent: Node) -> void:
	host._clear_children(parent)


func _house_world(pos: Vector2i) -> Vector3:
	return host._house_world(pos)


func _add_box(parent: Node3D, node_name: String, local_position: Vector3, box_size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_box(parent, node_name, local_position, box_size, material)


func _add_cylinder(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	return host._add_cylinder(parent, node_name, local_position, radius, height, material)


func _add_label(parent: Node3D, node_name: String, text_value: String, local_position: Vector3, color: Color, font_size: int) -> Label3D:
	return host._add_label(parent, node_name, text_value, local_position, color, font_size)


func _material(color: Color, transparent: bool = false, emission_strength: float = 0.0) -> StandardMaterial3D:
	return host._material(color, transparent, emission_strength)


func _set_house_camera() -> void:
	host._set_house_camera()


func can_place_selected_offer() -> bool:
	return host.can_place_selected_offer()


func _placed_room_size_counts() -> Dictionary:
	return host._placed_room_size_counts()


func build_house_world() -> void:
	if build_preview_tween != null and build_preview_tween.is_valid():
		build_preview_tween.kill()
	build_preview_tween = null
	_clear_children(house_root)
	# Scale the complete house presentation as one unit. Logical room positions,
	# HOUSE_CELL and battle coordinates remain unchanged; composer furniture,
	# interaction slots, tokens, bridges and frontiers stay aligned together.
	house_root.scale = Vector3.ONE * VISUAL_CELL_SCALE
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		_add_room_mesh(pos, room_rules.placed[pos])
	if kenney_build_lab_mode:
		_add_kenney_formal_composer()
	else:
		_add_room_bridges()
	if phase != "world_boss":
		for frontier in room_rules.frontiers():
			_add_frontier_mesh(frontier, phase == "build" and frontier == selected_frontier)
	if phase == "build" and not build_offers.is_empty():
		_add_build_preview()
	_add_house_player()
	if hovered_house_cell != INVALID_CELL and room_rules.placed.has(hovered_house_cell):
		_add_move_hover_mesh(hovered_house_cell)
	if phase != "combat":
		_set_house_camera()


func _add_kenney_formal_composer() -> void:
	var records_by_floor: Dictionary = {}
	for record: Dictionary in _formal_instance_records_in_connection_order():
		var room: Dictionary = record["room"]
		var floor_index := int(room.get("floor", 0))
		if not records_by_floor.has(floor_index):
			records_by_floor[floor_index] = []
		(records_by_floor[floor_index] as Array).append(record)
	var floors: Array = records_by_floor.keys()
	floors.sort()
	for raw_floor: Variant in floors:
		_add_kenney_formal_floor_composer(int(raw_floor), records_by_floor[raw_floor] as Array)


func _add_kenney_formal_floor_composer(floor_index: int, records: Array) -> void:
	if records.is_empty():
		return
	var composer := PCG_HAND_LAYOUT_LAB.instantiate() as Node3D
	composer.name = "KenneyFormalComposer" if floor_index == 0 else "KenneyFormalComposer_Floor_%d" % floor_index
	composer.generation_seed = run_seed + floor_index * 997
	composer.animate_room_build = false
	# Room identity and state live in the HUD. Floating labels break the
	# miniature-photography read and obscure props when rooms overlap on screen.
	composer.show_room_ids = false
	composer.kenney_only = true
	composer.use_kaykit_room_shell = true
	composer.unify_room_floor_finish = large_room_mix_test_mode
	composer.open_visited_connections = true
	composer.show_summary_title = false
	# A floor can contain islands that are connected by a stair outside the
	# floor's local footprint. They are valid presentation groups, not errors.
	composer.allow_disconnected_layout = true
	var floor_origin := _formal_floor_origin(records)
	composer.explicit_connection_edges = _formal_connection_edge_keys_for_floor(floor_index, floor_origin)
	composer.explicit_open_edges = _formal_outer_open_edge_keys_for_floor(floor_index, floor_origin)
	composer.scale = Vector3.ONE * (HOUSE_CELL / 1.55)
	composer.position = Vector3(0.0, _formal_floor_height(records), 0.0)
	composer.set_meta("visual_cell_scale", VISUAL_CELL_SCALE)
	composer.set_meta("floor", floor_index)
	var layout := composer.get_node("Layout") as Node3D
	for existing: Node in layout.get_children():
		layout.remove_child(existing)
		existing.free()
	for record: Dictionary in records:
		var room: Dictionary = record["room"]
		var origin_raw: Array = room.get("origin", [0, 0])
		var origin := Vector2i(int(origin_raw[0]), int(origin_raw[1]))
		var piece := Node3D.new()
		piece.name = "Placed_%s" % str(record["id"]).replace("@", "_").replace(",", "_")
		piece.set_script(PCG_HAND_ROOM_SCRIPT)
		piece.set("room_id", str(record["id"]))
		piece.set("shape_id", str(room.get("footprint_kind", "single")))
		piece.set("elevated", bool(room.get("elevated", false)))
		piece.set_meta("room_name", str(room.get("name", "房间")))
		piece.set_meta("room_type", str(room.get("id", "")))
		piece.set_meta("revealed", bool(room.get("revealed", false)))
		piece.set_meta("visited", bool(room.get("visited", false)))
		piece.set_meta("completed", bool(room.get("completed", false)))
		piece.set_meta("floor", floor_index)
		piece.set_meta("is_current", str(record["id"]) == str(room_rules.placed[current_room_pos].get("instance_id", "")))
		# Each floor has its own formal grid. The composer is then moved vertically
		# as a whole, so floor-local occupancy can never collide with another floor.
		var local_origin := origin - floor_origin
		piece.position = Vector3(float(local_origin.x) * 1.55, 0.0, float(local_origin.y) * 1.55)
		piece.rotation.y = float(int(room.get("rotation", 0))) * PI * 0.5
		layout.add_child(piece)
		# DIAGNOSTIC: log every formal room's id/room_type and whether a template
		# override file exists for it. This shows why a saved template may not line
		# up with the room it was meant for in the live game.
		var _base_id := RoomArtRegistry.base_room_id(str(room.get("id", "")))
		var _has_ov := not RoomArtRegistry.load_override(_base_id).is_empty()
		print("[OVERRIDE] compose room=%s room_id=%s room_type=%s override=%s" % [piece.name, str(record["id"]), str(room.get("id", "")), "YES" if _has_ov else "no"])
	house_root.add_child(composer)


func _formal_floor_origin(records: Array) -> Vector2i:
	if records.is_empty():
		return Vector2i.ZERO
	var room: Dictionary = records[0]["room"]
	var origin_raw: Array = room.get("origin", [0, 0])
	return _floor_origin(room, Vector2i(int(origin_raw[0]), int(origin_raw[1])))


func _formal_floor_height(records: Array) -> float:
	if records.is_empty():
		return 0.0
	return float((records[0]["room"] as Dictionary).get("floor_height", 0.0))


func _floor_origin(room: Dictionary, fallback_origin: Vector2i) -> Vector2i:
	var raw_origin: Variant = room.get("floor_origin", [])
	if raw_origin is Array and (raw_origin as Array).size() >= 2:
		return Vector2i(int((raw_origin as Array)[0]), int((raw_origin as Array)[1]))
	if int(room.get("floor", 0)) != 0:
		return fallback_origin
	return Vector2i.ZERO


func _formal_instance_records_in_connection_order() -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos]
		var instance_id := str(room.get("instance_id", "room@%d,%d" % [pos.x, pos.y]))
		if not by_id.has(instance_id):
			by_id[instance_id] = {"id": instance_id, "room": room, "cells": []}
		(by_id[instance_id]["cells"] as Array).append(pos)
	var result: Array[Dictionary] = []
	if by_id.is_empty():
		return result
	var start_id := str(room_rules.placed.get(Vector2i.ZERO, {}).get("instance_id", by_id.keys()[0]))
	var queued: Dictionary = {start_id: true}
	var queue: Array[String] = [start_id]
	while not queue.is_empty():
		var instance_id: String = queue.pop_front()
		if not by_id.has(instance_id):
			continue
		var record: Dictionary = by_id[instance_id]
		result.append(record)
		for cell: Vector2i in record["cells"]:
			for side in range(4):
				var neighbor: Vector2i = cell + RoomRules.DIRS[side]
				if not room_rules.placed.has(neighbor) or not room_rules.cell_has_door(cell, side) or not room_rules.cell_has_door(neighbor, (side + 2) % 4):
					continue
				var neighbor_id := str(room_rules.placed[neighbor].get("instance_id", ""))
				if neighbor_id == instance_id or queued.has(neighbor_id):
					continue
				queued[neighbor_id] = true
				queue.append(neighbor_id)
	var remaining_ids: Array = by_id.keys()
	remaining_ids.sort()
	for raw_id: Variant in remaining_ids:
		var instance_id := str(raw_id)
		if not queued.has(instance_id):
			result.append(by_id[instance_id])
	return result


func _formal_connection_edge_keys() -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		for side in [1, 2]:
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if not room_rules.placed.has(neighbor) or room_rules.same_instance(pos, neighbor):
				continue
			if room_rules.cell_has_door(pos, side) and room_rules.cell_has_door(neighbor, (side + 2) % 4):
				result[_grid_edge_key(pos, neighbor)] = true
	return result


func _formal_outer_open_edge_keys() -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		for side in range(4):
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if room_rules.placed.has(neighbor):
				continue
			if room_rules.cell_has_door(pos, side):
				result[_grid_edge_key(pos, neighbor)] = true
	return result


func _formal_connection_edge_keys_for_floor(floor_index: int, floor_origin: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos]
		if int(room.get("floor", 0)) != floor_index:
			continue
		for side in [1, 2]:
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if not room_rules.placed.has(neighbor) or room_rules.same_instance(pos, neighbor):
				continue
			var neighbor_room: Dictionary = room_rules.placed[neighbor]
			if int(neighbor_room.get("floor", 0)) != floor_index:
				continue
			if room_rules.cell_has_door(pos, side) and room_rules.cell_has_door(neighbor, (side + 2) % 4):
				result[_grid_edge_key(pos - floor_origin, neighbor - floor_origin)] = true
	return result


func _formal_outer_open_edge_keys_for_floor(floor_index: int, floor_origin: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for raw_pos: Variant in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		var room: Dictionary = room_rules.placed[pos]
		if int(room.get("floor", 0)) != floor_index:
			continue
		for side in range(4):
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if room_rules.placed.has(neighbor):
				continue
			if room_rules.cell_has_door(pos, side):
				result[_grid_edge_key(pos - floor_origin, neighbor - floor_origin)] = true
	return result

func _grid_edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a if a.y < b.y or (a.y == b.y and a.x < b.x) else b
	var second := b if first == a else a
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]


func _add_room_mesh(pos: Vector2i, room: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Room_%d_%d" % [pos.x, pos.y]
	node.set_meta("floor", int(room.get("floor", 0)))
	node.position = _house_world(pos)
	house_root.add_child(node)
	_populate_room_visual(node, pos, room)


func _populate_room_visual(node: Node3D, pos: Vector2i, room: Dictionary) -> void:
	_clear_children(node)
	if kenney_build_lab_mode:
		return
	var revealed := bool(room.get("revealed", false)) or bool(room.get("completed", false))
	var kind := str(room.get("kind", "quiet"))
	var accent := COL_TEAL
	if not revealed:
		accent = Color("46545b")
	elif kind == "combat":
		accent = COL_MAGENTA
	elif kind == "event":
		accent = Color("7964a5")
	if room_rules.same_instance(pos, current_room_pos):
		accent = COL_GOLD
	_add_box(node, "Base", Vector3.ZERO + Vector3(0, 0.14, 0), Vector3(3.05, 0.28, 3.05), _material(accent.darkened(0.35)))
	_add_box(node, "Floor", Vector3(0, 0.31, 0), Vector3(2.82, 0.12, 2.82), _material(COL_PAPER if revealed else Color("26363d")))
	var doors: Array = room.get("doors", [false, false, false, false])
	for side in range(4):
		if room_rules.same_instance(pos, pos + RoomRules.DIRS[side]):
			continue
		_add_room_edge(node, side, bool(doors[side]), accent)
	var decor_count := 0
	if room_rules.is_instance_anchor(pos):
		var decor_root := Node3D.new()
		decor_root.name = "RoomDecor"
		decor_root.rotation.y = -float(int(room.get("rotation", 0))) * PI * 0.5
		node.add_child(decor_root)
		decor_count = RoomArtRegistry.decorate(decor_root, room, revealed)
	var label_text := str(room.get("name", "房间")) if revealed else "?"
	var label_y := 2.10 if decor_count > 0 else 1.18
	if room_rules.is_instance_anchor(pos):
		_add_label(node, "Label", "%s · %d格" % [label_text, int(room.get("room_size", 1))], Vector3(0, label_y, 0), accent if revealed else COL_GOLD, 44)


func _add_room_edge(parent: Node3D, side: int, has_door: bool, color: Color) -> void:
	var wall_height := 0.55
	var wall_thickness := 0.14
	if side == 0 or side == 2:
		var z := -1.42 if side == 0 else 1.42
		if has_door:
			_add_box(parent, "DoorEdge", Vector3(-1.02, 0.68, z), Vector3(0.72, wall_height, wall_thickness), _material(color))
			_add_box(parent, "DoorEdge", Vector3(1.02, 0.68, z), Vector3(0.72, wall_height, wall_thickness), _material(color))
		else:
			_add_box(parent, "Wall", Vector3(0, 0.68, z), Vector3(2.82, wall_height, wall_thickness), _material(color))
	else:
		var x := 1.42 if side == 1 else -1.42
		if has_door:
			_add_box(parent, "DoorEdge", Vector3(x, 0.68, -1.02), Vector3(wall_thickness, wall_height, 0.72), _material(color))
			_add_box(parent, "DoorEdge", Vector3(x, 0.68, 1.02), Vector3(wall_thickness, wall_height, 0.72), _material(color))
		else:
			_add_box(parent, "Wall", Vector3(x, 0.68, 0), Vector3(wall_thickness, wall_height, 2.82), _material(color))


func _add_room_bridges() -> void:
	for raw_pos in room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		for side in [1, 2]:
			var neighbor: Vector2i = pos + RoomRules.DIRS[side]
			if not room_rules.placed.has(neighbor) or not room_rules.cell_has_door(pos, side):
				continue
			var bridge_size := Vector3(0.55, 0.12, 2.82) if side == 1 else Vector3(2.82, 0.12, 0.55)
			var bridge := _add_box(house_root, "RoomJoin" if room_rules.same_instance(pos, neighbor) else "Bridge", (_house_world(pos) + _house_world(neighbor)) * 0.5 + Vector3(0, 0.24, 0), bridge_size, _material(COL_PAPER))
			bridge.set_meta("floor", int(room_rules.placed[pos].get("floor", 0)))


func _add_frontier_mesh(pos: Vector2i, selected: bool) -> void:
	var node := Node3D.new()
	node.name = "Frontier_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	var color := COL_GOLD if selected else Color("c88b2f")
	var transparent := Color(color, 0.72 if selected else 0.48)
	var socket_size := 0.78 if selected else 0.58
	node.rotation.y = PI * 0.25
	_add_box(node, "BuildSocket", Vector3(0, 0.12, 0), Vector3(socket_size, 0.12, socket_size), _material(transparent, true))
	_add_box(node, "SocketCore", Vector3(0, 0.20, 0), Vector3(socket_size * 0.48, 0.045, socket_size * 0.48), _material(color))
	# In-world television signal bars replace the editor-like floating plus.
	for bar_index in range(3):
		var height := 0.12 + float(bar_index) * 0.10
		_add_box(node, "SignalBar_%d" % bar_index, Vector3(-0.18 + float(bar_index) * 0.18, 0.25 + height * 0.5, 0), Vector3(0.07, height, 0.07), _material(color, false, 0.04 if selected else 0.0))


func _add_build_preview() -> void:
	var room: Dictionary = build_offers[selected_offer]
	var node := Node3D.new()
	node.name = "BuildPreview"
	var preview_origin: Vector2i = room_rules.placement_origin(selected_frontier, room, offer_rotation)
	node.position = _house_world(preview_origin) + Vector3(0, 0.20, 0)
	node.rotation.y = -float(offer_rotation) * PI * 0.5
	house_root.add_child(node)
	var preview_room := room.duplicate(true)
	preview_room["revealed"] = false
	preview_room["completed"] = false
	preview_room["doors"] = room_rules.normalize_doors(room.get("doors", []))
	if kenney_build_lab_mode:
		for offset: Vector2i in room_rules.footprint_cells(room):
			_add_kenney_preview_cell(node, offset)
	else:
		_populate_room_visual(node, selected_frontier, preview_room)
		for offset: Vector2i in room_rules.footprint_cells(room):
			if offset == Vector2i.ZERO:
				continue
			var footprint_cell := Node3D.new()
			footprint_cell.name = "Footprint_%d_%d" % [offset.x, offset.y]
			footprint_cell.position = Vector3(float(offset.x) * HOUSE_CELL, 0.0, float(offset.y) * HOUSE_CELL)
			node.add_child(footprint_cell)
			_add_box(footprint_cell, "Base", Vector3(0, 0.14, 0), Vector3(3.05, 0.28, 3.05), _material(Color("27343a")))
			_add_box(footprint_cell, "Floor", Vector3(0, 0.31, 0), Vector3(2.82, 0.12, 2.82), _material(Color("26363d")))
	var validity := _add_cylinder(node, "PreviewValidity", Vector3(0, 0.14, 0), 1.58, 0.08, _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.72), true, 0.08))
	validity.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_label(node, "PreviewRotation", "%d°" % (offer_rotation * 90), Vector3(0, 1.68, 0), Color.WHITE, 30)
	_update_build_preview_validity(node)


func _add_kenney_preview_cell(parent: Node3D, offset: Vector2i) -> void:
	var cell_root := Node3D.new()
	cell_root.name = "KenneyPreview_%d_%d" % [offset.x, offset.y]
	cell_root.position = Vector3(float(offset.x) * HOUSE_CELL, 0.0, float(offset.y) * HOUSE_CELL)
	parent.add_child(cell_root)
	_add_box(cell_root, "GhostBase", Vector3(0, 0.10, 0), Vector3(HOUSE_CELL * 0.94, 0.16, HOUSE_CELL * 0.94), _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.30), true))
	var packed := load(KAYKIT_DUNGEON_ROOT + "floor_wood_large.gltf.glb") as PackedScene
	if packed == null:
		return
	var floor_model := packed.instantiate() as Node3D
	if floor_model == null:
		return
	floor_model.name = "FloorModel"
	floor_model.position.y = 0.20
	floor_model.scale = Vector3.ONE * (HOUSE_CELL / 4.0)
	cell_root.add_child(floor_model)
	var ghost_material := _material(Color(COL_GREEN if can_place_selected_offer() else COL_RED, 0.34), true, 0.05)
	for raw_mesh: Node in floor_model.find_children("*", "MeshInstance3D", true, false):
		(raw_mesh as MeshInstance3D).material_override = ghost_material


func _update_build_preview_validity(preview: Node3D) -> void:
	var valid := can_place_selected_offer()
	var validity := preview.get_node_or_null("PreviewValidity") as MeshInstance3D
	if validity != null:
		validity.material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.72), true, 0.08)
	for raw_ghost: Node in preview.find_children("GhostBase", "MeshInstance3D", true, false):
		(raw_ghost as MeshInstance3D).material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.30), true)
	for preview_cell: Node in preview.find_children("KenneyPreview_*", "Node3D", true, false):
		var model := preview_cell.get_node_or_null("FloorModel")
		if model != null:
			for raw_mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
				(raw_mesh as MeshInstance3D).material_override = _material(Color(COL_GREEN if valid else COL_RED, 0.34), true, 0.05)
	var label := preview.get_node_or_null("PreviewRotation") as Label3D
	if label != null:
		label.text = "%d° · %s" % [offer_rotation * 90, "可摆" if valid else "门不合"]
		label.modulate = COL_GREEN if valid else COL_RED


func _add_house_player() -> void:
	var node := Node3D.new()
	node.name = "LiliToken"
	var interaction_slot := claim_room_interaction_slot("player:lili", current_room_pos)
	if interaction_slot.is_empty():
		node.position = _house_world(current_room_pos)
		node.rotation.y = house_player_facing_yaw
	else:
		node.position = _interaction_slot_house_position(interaction_slot, "position")
		node.rotation.y = float(interaction_slot.get("facing_yaw", house_player_facing_yaw))
		house_player_facing_yaw = node.rotation.y
		node.set_meta("interaction_room_id", str(interaction_slot.get("room_id", "")))
		node.set_meta("interaction_cell", interaction_slot.get("cell", current_room_pos))
		node.set_meta("interaction_slot_index", int(interaction_slot.get("slot_index", -1)))
		node.set_meta("interaction_kind", str(interaction_slot.get("kind", "stand")))
		node.set_meta("interaction_pose", str(interaction_slot.get("pose", "stand")))
		node.set_meta("interaction_asset_id", str(interaction_slot.get("asset_id", "")))
		node.set_meta("interaction_anchor", _interaction_slot_house_position(interaction_slot, "anchor_position"))
	house_root.add_child(node)
	_add_cylinder(node, "TokenBase", Vector3(0, 0.09, 0), 0.48, 0.12, _material(COL_TEAL, false, 0.05))
	var presenter := CharacterPresenter.new()
	presenter.name = "Presenter"
	presenter.position = Vector3(0.0, 0.14, 0.0)
	node.add_child(presenter)
	presenter.configure("player", (presentation.get("actors", {}).get("player", {}) as Dictionary))
	if not interaction_slot.is_empty() and presenter.has_method("set_interaction_pose"):
		presenter.set_interaction_pose(str(interaction_slot.get("pose", "stand")), str(interaction_slot.get("kind", "stand")))


func room_interaction_slots(target: Vector2i) -> Array[Dictionary]:
	var composer: Node3D = house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null or not composer.has_method("interaction_slots_for_cell"):
		return []
	return composer.interaction_slots_for_cell(target)


func claim_room_interaction_slot(actor_id: String, target: Vector2i, preferred_kind: String = "") -> Dictionary:
	if not room_rules.placed.has(target):
		return {}
	var slots := room_interaction_slots(target)
	if slots.is_empty():
		return {}
	var room_id := str(room_rules.placed[target].get("instance_id", ""))
	var existing: Dictionary = house_actor_slot_assignments.get(actor_id, {})
	if str(existing.get("room_id", "")) == room_id and existing.has("cell") and existing["cell"] == target:
		var existing_index := int(existing.get("slot_index", -1))
		if existing_index >= 0 and existing_index < slots.size():
			return slots[existing_index].duplicate(true)
	var occupied: Dictionary = {}
	for raw_actor_id: Variant in house_actor_slot_assignments.keys():
		if str(raw_actor_id) == actor_id:
			continue
		var assignment: Dictionary = house_actor_slot_assignments[raw_actor_id]
		if str(assignment.get("room_id", "")) == room_id and assignment.has("cell") and assignment["cell"] == target:
			occupied[int(assignment.get("slot_index", -1))] = true
	var chosen_index := -1
	if not preferred_kind.is_empty():
		for slot_index in range(slots.size()):
			if not occupied.has(slot_index) and str(slots[slot_index].get("kind", "")) == preferred_kind:
				chosen_index = slot_index
				break
	if chosen_index < 0:
		for slot_index in range(slots.size()):
			if not occupied.has(slot_index):
				chosen_index = slot_index
				break
	if chosen_index < 0:
		return {}
	var chosen_slot: Dictionary = slots[chosen_index]
	house_actor_slot_assignments[actor_id] = {
		"room_id": room_id,
		"cell": target,
		"slot_index": chosen_index,
		"kind": str(chosen_slot.get("kind", "stand")),
		"pose": str(chosen_slot.get("pose", "stand")),
		"asset_id": str(chosen_slot.get("asset_id", "")),
	}
	return slots[chosen_index].duplicate(true)


func release_room_interaction_slot(actor_id: String) -> void:
	house_actor_slot_assignments.erase(actor_id)


func actor_interaction_state(actor_id: String) -> Dictionary:
	return (house_actor_slot_assignments.get(actor_id, {}) as Dictionary).duplicate(true)


func _house_interaction_target_position(actor_id: String, target: Vector2i) -> Vector3:
	var slot := claim_room_interaction_slot(actor_id, target)
	if slot.is_empty():
		return _house_world(target)
	return _interaction_slot_house_position(slot, "position")


func _interaction_slot_house_position(slot: Dictionary, field: String) -> Vector3:
	var local_position: Vector3 = slot.get(field, Vector3.ZERO)
	var composer := house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null:
		return local_position
	return composer.transform * local_position


func _add_move_hover_mesh(pos: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "MoveHover_%d_%d" % [pos.x, pos.y]
	node.position = _house_world(pos)
	house_root.add_child(node)
	_add_box(node, "MoveHoverPad", Vector3(0, 0.15, 0), Vector3(HOUSE_CELL * 0.94, 0.10, HOUSE_CELL * 0.94), _material(Color(0.45, 0.88, 1.0, 0.38), true))


func _apply_current_room_cutaway() -> void:
	if not room_rules.placed.has(current_room_pos):
		return
	var composer: Node3D = house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null or camera == null or not composer.has_method("apply_camera_cutaway"):
		return
	var viewer_axis: Vector3 = camera.global_transform.basis.z
	var local_viewer_axis: Vector3 = composer.global_transform.basis.inverse() * viewer_axis
	composer.apply_camera_cutaway(current_room_pos, Vector2(local_viewer_axis.x, local_viewer_axis.z))


func pcg_cutaway_debug_text() -> String:
	var composer: Node3D = house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null or not composer.has_method("cutaway_debug_summary"):
		return "PCG 诊断等待生成"
	return str(composer.cutaway_debug_summary())


func pcg_room_state_debug_text() -> String:
	var composer: Node3D = house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	if composer == null or not composer.has_method("room_state_debug_summary"):
		return "房态等待生成"
	return "%s · 扩建插槽%d" % [str(composer.room_state_debug_summary()), room_rules.frontiers().size()]


func large_room_mix_debug_text() -> String:
	var counts := _placed_room_size_counts()
	return "节奏 1格 %d/4 · 3格 %d/6 · 5格 %d/2" % [int(counts[1]), int(counts[3]), int(counts[5])]


func frontier_markers_are_compact() -> bool:
	var marker_count := 0
	for raw_marker: Node in house_root.find_children("Frontier_*", "Node3D", false, false):
		var marker := raw_marker as Node3D
		var socket := marker.get_node_or_null("BuildSocket") as MeshInstance3D
		if socket == null or not (socket.mesh is BoxMesh):
			return false
		if (socket.mesh as BoxMesh).size.x > HOUSE_CELL * 0.35:
			return false
		marker_count += 1
	return marker_count == room_rules.frontiers().size()
