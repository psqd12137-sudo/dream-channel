extends RefCounted

const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const OPPOSITE := [2, 3, 0, 1]

var placed: Dictionary = {}
## Explicit vertical transitions for multi-floor maps. The current room key
## remains Vector2i for save compatibility; each link connects two physical
## cells and carries the authored stair label/type.
var stair_links: Array[Dictionary] = []


func reset(start_room: Dictionary) -> void:
	placed.clear()
	stair_links.clear()
	var room := start_room.duplicate(true)
	room["rotation"] = 0
	room["doors"] = normalize_doors(room.get("doors", [false, false, false, false]))
	room["pos"] = Vector2i.ZERO
	room["origin"] = [0, 0]
	var occupied := world_cells(Vector2i.ZERO, room, 0)
	var serialized_cells: Array = []
	for cell: Vector2i in occupied:
		serialized_cells.append([cell.x, cell.y])
	room["world_cells"] = serialized_cells
	room["open_edges"] = _resolved_open_edges(occupied, room["doors"])
	room["instance_id"] = "%s@0,0" % str(room.get("id", "start"))
	room["completed"] = true
	for cell: Vector2i in occupied:
		placed[cell] = room


func normalize_doors(raw: Array) -> Array:
	var doors := [false, false, false, false]
	for i in range(mini(4, raw.size())):
		doors[i] = bool(raw[i])
	return doors


func rotated_doors(raw: Array, turns: int) -> Array:
	var source := normalize_doors(raw)
	var result := [false, false, false, false]
	var normalized := posmod(turns, 4)
	for i in range(4):
		result[(i + normalized) % 4] = source[i]
	return result


func footprint_cells(room: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_cell in room.get("footprint", [[0, 0]]):
		if raw_cell is Array and raw_cell.size() >= 2:
			result.append(Vector2i(int(raw_cell[0]), int(raw_cell[1])))
	if result.is_empty():
		result.append(Vector2i.ZERO)
	return result


func rotated_cells(room: Dictionary, turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var normalized := posmod(turns, 4)
	for source: Vector2i in footprint_cells(room):
		var cell := source
		for _step in range(normalized):
			cell = Vector2i(-cell.y, cell.x)
		result.append(cell)
	return result


func world_cells(target: Vector2i, room: Dictionary, rotation: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in rotated_cells(room, rotation):
		result.append(target + offset)
	return result


func can_place(target: Vector2i, room: Dictionary, rotation: int) -> bool:
	return not resolve_placement(target, room, rotation).is_empty()


func resolve_placement(target: Vector2i, room: Dictionary, rotation: int) -> Dictionary:
	var doors := rotated_doors(room.get("doors", []), rotation)
	for entrance_offset: Vector2i in rotated_cells(room, rotation):
		var origin := target - entrance_offset
		var candidate_cells := world_cells(origin, room, rotation)
		if _candidate_is_legal(target, candidate_cells, doors):
			return {"origin": origin, "cells": candidate_cells}
	return {}


func placement_origin(target: Vector2i, room: Dictionary, rotation: int) -> Vector2i:
	var resolved := resolve_placement(target, room, rotation)
	return resolved.get("origin", target) as Vector2i


func _candidate_is_legal(selected_target: Vector2i, candidate_cells: Array[Vector2i], doors: Array) -> bool:
	var candidate_set: Dictionary = {}
	for cell: Vector2i in candidate_cells:
		if placed.has(cell):
			return false
		candidate_set[cell] = true
	var candidate_open_edges := _resolved_open_edges(candidate_cells, doors)
	var touches_room := false
	var creates_connection := false
	var connects_selected_target := false
	for cell: Vector2i in candidate_cells:
		for i in range(4):
			var neighbor_pos: Vector2i = cell + DIRS[i]
			if candidate_set.has(neighbor_pos) or not placed.has(neighbor_pos):
				continue
			touches_room = true
			var neighbor_open := cell_has_door(neighbor_pos, OPPOSITE[i])
			var candidate_open := _edge_key(cell, neighbor_pos) in candidate_open_edges
			if candidate_open != neighbor_open:
				return false
			if candidate_open:
				creates_connection = true
				if cell == selected_target:
					connects_selected_target = true
	return touches_room and creates_connection and connects_selected_target


func place(target: Vector2i, room: Dictionary, rotation: int) -> bool:
	var resolved := resolve_placement(target, room, rotation)
	if resolved.is_empty():
		return false
	var origin: Vector2i = resolved["origin"]
	var occupied: Array[Vector2i] = resolved["cells"]
	var instance := room.duplicate(true)
	instance["rotation"] = posmod(rotation, 4)
	instance["doors"] = rotated_doors(room.get("doors", []), rotation)
	instance["pos"] = target
	instance["origin"] = [origin.x, origin.y]
	instance["instance_id"] = "%s@%d,%d" % [str(room.get("id", "room")), origin.x, origin.y]
	var serialized_cells: Array = []
	for cell: Vector2i in occupied:
		serialized_cells.append([cell.x, cell.y])
	instance["world_cells"] = serialized_cells
	instance["open_edges"] = _resolved_open_edges(occupied, instance["doors"])
	instance["completed"] = false
	for cell: Vector2i in occupied:
		placed[cell] = instance
	return true


func valid_rotations(target: Vector2i, room: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for rotation in range(4):
		if can_place(target, room, rotation):
			result.append(rotation)
	return result


func frontiers() -> Array[Vector2i]:
	var unique: Dictionary = {}
	for raw_pos in placed.keys():
		var pos: Vector2i = raw_pos
		for i in range(4):
			if not cell_has_door(pos, i):
				continue
			var target: Vector2i = pos + DIRS[i]
			if not placed.has(target):
				unique[target] = true
	var result: Array[Vector2i] = []
	for raw_target in unique.keys():
		result.append(raw_target)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return result


func same_instance(a: Vector2i, b: Vector2i) -> bool:
	if not placed.has(a) or not placed.has(b):
		return false
	return str(placed[a].get("instance_id", "")) == str(placed[b].get("instance_id", ""))


func cell_has_door(pos: Vector2i, side: int) -> bool:
	if not placed.has(pos) or side < 0 or side >= 4:
		return false
	if same_instance(pos, pos + DIRS[side]):
		return true
	var open_edges: Array = placed[pos].get("open_edges", [])
	if not open_edges.is_empty():
		return _edge_key(pos, pos + DIRS[side]) in open_edges
	var doors: Array = placed[pos].get("doors", [false, false, false, false])
	return doors.size() >= 4 and bool(doors[side])


func _resolved_open_edges(cells: Array[Vector2i], doors: Array) -> Array[String]:
	var result: Array[String] = []
	if cells.is_empty():
		return result
	var cell_set: Dictionary = {}
	var centroid := Vector2.ZERO
	for cell: Vector2i in cells:
		cell_set[cell] = true
		centroid += Vector2(cell)
	centroid /= float(cells.size())
	for side in range(4):
		if side >= doors.size() or not bool(doors[side]):
			continue
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in cells:
			if not cell_set.has(cell + DIRS[side]):
				candidates.append(cell)
		if candidates.is_empty():
			continue
		var tangent_axis := 0 if side in [0, 2] else 1
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var distance_a := absf((float(a.x) if tangent_axis == 0 else float(a.y)) - (centroid.x if tangent_axis == 0 else centroid.y))
			var distance_b := absf((float(b.x) if tangent_axis == 0 else float(b.y)) - (centroid.x if tangent_axis == 0 else centroid.y))
			if not is_equal_approx(distance_a, distance_b):
				return distance_a < distance_b
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		var socket: Vector2i = candidates[0]
		result.append(_edge_key(socket, socket + DIRS[side]))
	return result


func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var first := a if a.y < b.y or (a.y == b.y and a.x < b.x) else b
	var second := b if first == a else a
	return "%d,%d|%d,%d" % [first.x, first.y, second.x, second.y]


func is_instance_anchor(pos: Vector2i) -> bool:
	if not placed.has(pos):
		return false
	var origin: Array = placed[pos].get("origin", [pos.x, pos.y])
	return origin.size() >= 2 and pos == Vector2i(int(origin[0]), int(origin[1]))


func set_instance_flag(pos: Vector2i, key: String, value: Variant) -> void:
	if not placed.has(pos):
		return
	var instance_id := str(placed[pos].get("instance_id", ""))
	for raw_pos in placed.keys():
		var cell: Vector2i = raw_pos
		var room: Dictionary = placed[cell]
		if str(room.get("instance_id", "")) == instance_id:
			room[key] = value
			placed[cell] = room


func instance_count() -> int:
	var ids: Dictionary = {}
	for room: Dictionary in placed.values():
		ids[str(room.get("instance_id", ""))] = true
	return ids.size()
