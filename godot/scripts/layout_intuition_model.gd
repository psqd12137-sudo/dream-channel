extends RefCounted
## Isolated layout experiment. Uses formal placement/door rules; never writes saves.
const Rules = preload("res://scripts/room_rules.gd")
const NONE := Vector2i(-999, -999)
var rules = Rules.new()
var history: Array[Dictionary] = []
var options: Array[Dictionary] = [
	{"id":"living", "name":"补一间 · 客厅", "footprint_kind":"single", "footprint":[[0,0]], "doors":[true,true,true,true]},
	{"id":"loft", "name":"延伸 · 长廊", "footprint_kind":"line3", "footprint":[[0,0],[1,0],[2,0]], "doors":[true,true,true,true]},
	{"id":"hall", "name":"展开 · 大厅", "footprint_kind":"plus5", "footprint":[[0,0],[1,0],[-1,0],[0,1],[0,-1]], "doors":[true,true,true,true]},
]

func reset() -> void:
	history.clear()
	rules.reset(options[0])
	for cell in [Vector2i(0,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(2,1), Vector2i(2,0)]:
		rules.place(cell, options[0], 0)

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(4):
		var next: Vector2i = cell + Rules.DIRS[i]
		if rules.placed.has(next) and rules.cell_has_door(cell, i) and rules.cell_has_door(next, Rules.OPPOSITE[i]):
			result.append(next)
	return result

func route(blocked: Vector2i = NONE) -> Array[Vector2i]:
	var start := Vector2i.ZERO
	var goal := Vector2i(2,0)
	var queue: Array[Vector2i] = [start]
	var prev := {start: start}
	for cell: Vector2i in queue:
		if cell == goal:
			var result: Array[Vector2i] = [goal]
			while result[0] != start:
				result.push_front(prev[result[0]])
			return result
		for next: Vector2i in neighbors(cell):
			if next != blocked and not prev.has(next):
				prev[next] = cell
				queue.append(next)
	return []

func preview(target: Vector2i, index: int, rotation: int) -> Dictionary:
	var resolved: Dictionary = rules.resolve_placement(target, options[index], rotation)
	if resolved.is_empty():
		return {"valid":false, "cells":rules.world_cells(target, options[index], rotation), "contacts":0, "loop":false}
	var edges: Array = rules._resolved_open_edges(resolved.cells, rules.rotated_doors(options[index].doors, rotation))
	var contacts := 0
	for cell: Vector2i in resolved.cells:
		for next: Vector2i in Rules.DIRS:
			if rules.placed.has(cell + next) and rules._edge_key(cell, cell + next) in edges:
				contacts += 1
	return {"valid":true, "cells":resolved.cells, "contacts":contacts, "loop":contacts > 1}

func place(target: Vector2i, index: int, rotation: int) -> bool:
	var before: Dictionary = rules.placed.duplicate(true)
	if not rules.place(target, options[index], rotation):
		return false
	history.append(before)
	return true

func undo() -> void:
	if not history.is_empty():
		rules.placed = history.pop_back()
