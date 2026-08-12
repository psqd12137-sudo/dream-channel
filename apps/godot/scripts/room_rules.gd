extends RefCounted

const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const OPPOSITE := [2, 3, 0, 1]

var placed: Dictionary = {}


func reset(start_room: Dictionary) -> void:
	placed.clear()
	var room := start_room.duplicate(true)
	room["rotation"] = 0
	room["doors"] = normalize_doors(room.get("doors", [false, false, false, false]))
	room["pos"] = Vector2i.ZERO
	room["completed"] = true
	placed[Vector2i.ZERO] = room


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


func can_place(target: Vector2i, room: Dictionary, rotation: int) -> bool:
	if placed.has(target):
		return false
	var doors := rotated_doors(room.get("doors", []), rotation)
	var touches_room := false
	var creates_connection := false
	for i in range(4):
		var neighbor_pos: Vector2i = target + DIRS[i]
		if not placed.has(neighbor_pos):
			continue
		touches_room = true
		var neighbor: Dictionary = placed[neighbor_pos]
		var neighbor_doors: Array = neighbor.get("doors", [false, false, false, false])
		if bool(doors[i]) != bool(neighbor_doors[OPPOSITE[i]]):
			return false
		if bool(doors[i]):
			creates_connection = true
	return touches_room and creates_connection


func place(target: Vector2i, room: Dictionary, rotation: int) -> bool:
	if not can_place(target, room, rotation):
		return false
	var instance := room.duplicate(true)
	instance["rotation"] = posmod(rotation, 4)
	instance["doors"] = rotated_doors(room.get("doors", []), rotation)
	instance["pos"] = target
	instance["completed"] = false
	placed[target] = instance
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
		var room: Dictionary = placed[pos]
		var doors: Array = room.get("doors", [false, false, false, false])
		for i in range(4):
			if not bool(doors[i]):
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
