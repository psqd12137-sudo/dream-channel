extends "res://scripts/combat_rules.gd"

const Programme = preload("res://scripts/overworld_boss_program.gd")
const RoomRules = preload("res://scripts/room_rules.gd")

# Boss combat uses the source map's occupied cells as its board. Room instances
# remain metadata for art/labels only; they are never movement nodes.
var graph: Dictionary = {}
var room_nodes: Dictionary = {} # physical cell -> one-cell presentation record
var room_instances: Dictionary = {} # instance id -> {name, cells, origin}
var cell_nodes: Dictionary = {} # physical cell -> same physical cell
var cell_floors: Dictionary = {} # physical cell -> authored floor index
var cell_elevations: Dictionary = {} # physical cell -> world height in logical units
var stair_links: Array[Dictionary] = []
var physical_cells: Array[Vector2i] = []
var anchors: Dictionary = {} # physical cell -> remaining charges
var broadcast := 0
var broadcast_max := 18
var finish_reason := ""
# Kept in snapshots for backward compatibility with older previews; it no
# longer drives Boss actions or defeat conditions in the turn-based finale.
var free_elapsed := 0.0
var move_cooldown := 0.0
var journal: Array = []
var replaying := false
var initial: Dictionary = {}
var error := ""

func initialize(rooms, start: Vector2i, boss: Dictionary, defs: Dictionary, starter: Array, seed: int, rules: Dictionary, relics: Array) -> void:
	graph.clear()
	room_nodes.clear()
	room_instances.clear()
	cell_nodes.clear()
	cell_floors.clear()
	cell_elevations.clear()
	stair_links.clear()
	physical_cells.clear()
	anchors.clear()
	var instance_cells: Dictionary = {}
	for raw_cell in rooms.placed.keys():
		var cell: Vector2i = raw_cell
		var room: Dictionary = rooms.placed[cell]
		# Unknown rooms stay unknown when the final map is revealed as a battle.
		if not bool(room.get("revealed", false)) and not bool(room.get("completed", false)):
			continue
		physical_cells.append(cell)
		var instance_id := str(room.get("instance_id", str(room.get("origin", [cell.x, cell.y]))))
		if not instance_cells.has(instance_id):
			instance_cells[instance_id] = []
			room_instances[instance_id] = {
				"id": instance_id,
				"name": str(room.get("name", instance_id)),
				"origin": _room_origin(room, cell),
				"cells": [],
			}
		instance_cells[instance_id].append(cell)
		room_instances[instance_id].cells.append(cell)
		room_nodes[cell] = {
			"id": instance_id,
			"name": str(room.get("name", instance_id)),
			"cell": cell,
			"cells": [cell],
			"origin": _room_origin(room, cell),
			"floor": int(room.get("floor", 0)),
			"elevation": float(room.get("floor_height", 0.0)),
			"floor_label": str(room.get("floor_label", "地面层")),
			"is_room_origin": cell == _room_origin(room, cell),
		}
		cell_floors[cell] = int(room.get("floor", 0))
		cell_elevations[cell] = float(room.get("floor_height", 0.0))
		cell_nodes[cell] = cell
		graph[cell] = []
	physical_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x
	)
	for cell: Vector2i in physical_cells:
		for side in range(4):
			var other: Vector2i = cell + RoomRules.DIRS[side]
			if not cell_nodes.has(other):
				continue
			var same_room := str(rooms.placed[cell].get("instance_id", "")) == str(rooms.placed[other].get("instance_id", ""))
			var through_door: bool = rooms.cell_has_door(cell, side) and rooms.cell_has_door(other, RoomRules.OPPOSITE[side])
			if (same_room or through_door) and other not in graph[cell]:
				graph[cell].append(other)
	for cell: Vector2i in physical_cells:
		graph[cell].sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or a.y == b.y and a.x < b.x
		)
	# Vertical transitions are explicit authored links, not accidental planar
	# adjacency. This lets the same combat graph represent stairs without
	# replacing the original room assets or changing save coordinates.
	for raw_link: Variant in rooms.stair_links:
		if not raw_link is Dictionary:
			continue
		var link: Dictionary = raw_link
		var from := _link_cell(link.get("from", INVALID_CELL))
		var to := _link_cell(link.get("to", INVALID_CELL))
		if from == INVALID_CELL or to == INVALID_CELL or not graph.has(from) or not graph.has(to):
			continue
		if to not in graph[from]:
			graph[from].append(to)
		if from not in graph[to]:
			graph[to].append(from)
		stair_links.append({"from": from, "to": to, "label": str(link.get("label", "楼梯")), "kind": str(link.get("kind", "stair"))})
	for cell: Vector2i in physical_cells:
		graph[cell].sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or a.y == b.y and a.x < b.x
		)
	var start_cell: Vector2i = cell_nodes.get(start, INVALID_CELL)
	if start_cell == INVALID_CELL:
		error = "终局起点必须位于已探索的大地图格子上。"
		return
	var reachable: Array[Vector2i] = []
	for cell: Vector2i in physical_cells:
		var path := _find_path(start_cell, cell)
		if not path.is_empty() and path.back() == cell:
			reachable.append(cell)
	if reachable.size() < 5:
		error = "终局需要至少5个通过格子和门洞连通的已探索格子。"
		return
	reachable.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := _path_distance(start_cell, a)
		var db := _path_distance(start_cell, b)
		return da > db or da == db and (a.y < b.y or a.y == b.y and a.x < b.x)
	)
	var spawn: Vector2i = reachable[0]
	# CombatRules keeps its historical non-negative spawn contract. The board
	# itself may contain negative overworld coordinates (the basement lane), so
	# choose a reachable non-negative spawn whenever one exists and leave the
	# physical coordinates untouched everywhere else.
	for candidate: Vector2i in reachable:
		if candidate.x >= 0 and candidate.y >= 0:
			spawn = candidate
			break
	# Prefer one anchor in each room instance, then fill remaining positions by
	# distance. All anchor keys are still physical battle cells.
	var chosen_instances: Dictionary = {}
	for cell: Vector2i in reachable:
		if cell == start_cell or cell == spawn:
			continue
		var instance_id := str(room_nodes[cell].id)
		if chosen_instances.has(instance_id):
			continue
		anchors[cell] = 2
		chosen_instances[instance_id] = true
		if anchors.size() == 4:
			break
	if anchors.size() < 4:
		for cell: Vector2i in reachable:
			if cell == start_cell or cell == spawn or anchors.has(cell):
				continue
			anchors[cell] = 2
			if anchors.size() == 4:
				break
	var board_min := physical_cells[0]
	var board_max := physical_cells[0]
	for cell: Vector2i in physical_cells:
		board_min.x = mini(board_min.x, cell.x)
		board_min.y = mini(board_min.y, cell.y)
		board_max.x = maxi(board_max.x, cell.x)
		board_max.y = maxi(board_max.y, cell.y)
	var enemy := {
		"id": "overworld_boss",
		"name": str(boss.get("name", "频道宿主")),
		"hp": int(boss.get("hp", 16)),
		"damage": 2,
		"toughness": 6,
		"action_points": 2,
		"attack_cost": 2,
		"spawn": [spawn.x, spawn.y],
		"archetype": "host",
		"traits": [],
	}
	initial = {
		"cell": [start_cell.x, start_cell.y],
		"rules": rules.duplicate(true),
		"deck": starter.duplicate(),
		"relics": relics.duplicate(),
		"seed": seed,
	}
	# cols/rows are only compatibility bounds for shared UI helpers; walkability
	# and pathing are overridden below and continue to use physical coordinates.
	setup({
		"cols": board_max.x - board_min.x + 1,
		"rows": board_max.y - board_min.y + 1,
		"player": [start_cell.x, start_cell.y],
		"player_facing": [0, 1],
	}, enemy, defs, starter, seed, rules, relics)
	host_fight = Programme.new()
	host_fight.prepare(self)

func _room_origin(room: Dictionary, fallback: Vector2i) -> Vector2i:
	var raw: Array = room.get("origin", [fallback.x, fallback.y])
	return Vector2i(int(raw[0]), int(raw[1])) if raw.size() >= 2 else fallback

func _link_cell(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return INVALID_CELL

func is_walkable(pos: Vector2i) -> bool:
	return graph.has(pos)

func _find_path(start: Vector2i, goal: Vector2i, blocked_cells: Dictionary = {}, _allow_portals: bool = true) -> Array[Vector2i]:
	if not graph.has(start) or not graph.has(goal):
		return []
	var queue: Array[Vector2i] = [start]
	var parents := {start: start}
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at == goal:
			var result: Array[Vector2i] = [goal]
			while result[0] != start:
				result.push_front(parents[result[0]])
			return result
		for next: Vector2i in graph.get(at, []):
			if not parents.has(next) and (not blocked_cells.has(next) or next == goal):
				parents[next] = at
				queue.append(next)
	return []

func _path_distance(start: Vector2i, goal: Vector2i) -> int:
	var path := _find_path(start, goal)
	return path.size() - 1 if not path.is_empty() else 999

func manhattan(a: Vector2i, b: Vector2i) -> int:
	return _path_distance(a, b)

func player_move_cost(target: Vector2i) -> int:
	var cost := super.player_move_cost(target)
	if is_walkable(target) and absf(float(cell_elevations.get(target, 0.0)) - float(cell_elevations.get(player_pos, 0.0))) > 0.01:
		cost += 1
	return cost

func _enemy_path_cost(path: Array[Vector2i]) -> int:
	var total := super._enemy_path_cost(path)
	for index in range(1, path.size()):
		if absf(float(cell_elevations.get(path[index], 0.0)) - float(cell_elevations.get(path[index - 1], 0.0))) > 0.01:
			total += 1
	return total

func _has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	return manhattan(a, b) <= 2

func _record(kind: String, value: Variant = 0) -> void:
	if not replaying:
		journal.append({"kind": kind, "value": value})

func player_reachable_cells() -> Array:
	var cells: Array = []
	if outcome != "":
		return cells
	for target: Vector2i in physical_cells:
		var path := player_path_to(target)
		if path.size() >= 2 and player_path_cost(path) <= energy:
			cells.append(target)
	return cells

func enemy_reachable_cells(state: CombatEnemyState, budget: int = -1) -> Array:
	var cells: Array = []
	if state == null or not state.alive():
		return cells
	var movement_budget := _enemy_turn_budget(state) if budget < 0 else budget
	var blocked := occupied_enemy_cells(state.id)
	for target: Vector2i in physical_cells:
		if target == state.pos or target == player_pos or target == decoy_pos:
			continue
		if blocked.has(target):
			continue
		var path := _find_path(state.pos, target, blocked, false)
		if path.size() >= 2 and _enemy_path_cost(path) <= movement_budget:
			cells.append(target)
	return cells

func _enemy_attack_coverage(state: CombatEnemyState, origin: Vector2i, can_see: bool = true) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not can_see:
		return cells
	for target: Vector2i in physical_cells:
		if target == origin or not is_walkable(target):
			continue
		var distance := manhattan(origin, target)
		var valid := false
		if state.has_trait("ranged"):
			valid = distance >= 2 and distance <= state.attack_range and _has_line_of_sight(origin, target)
		elif state.has_trait("beam"):
			valid = distance >= 2 and distance <= 3 and (origin.x == target.x or origin.y == target.y) and _has_line_of_sight(origin, target)
		elif state.has_trait("slam") or state.has_trait("guardBreak"):
			valid = distance <= 1
		else:
			valid = distance <= 1
		if valid:
			cells.append(target)
	return cells

func _ensure_patrol_goal(state: CombatEnemyState) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var blocked := occupied_enemy_cells(state.id)
	for cell: Vector2i in physical_cells:
		if cell == state.pos or not is_walkable(cell) or blocked.has(cell):
			continue
		if _find_path(state.pos, cell, blocked).size() >= 2:
			candidates.append(cell)
	if candidates.is_empty():
		state.patrol_goal = INVALID_CELL
		return INVALID_CELL
	var bias := player_pos if state.last_seen == INVALID_CELL else state.last_seen
	candidates.sort_custom(func(a: Vector2i, b: Vector2i):
		var da := manhattan(a, bias)
		var db := manhattan(b, bias)
		return da < db or da == db and (a.y < b.y or a.y == b.y and a.x < b.x)
	)
	state.patrol_goal = candidates[0]
	return state.patrol_goal

func step_to(cell: Vector2i) -> bool:
	if outcome != "" or move_cooldown > 0.0 or cell not in graph.get(player_pos, []):
		return false
	if not move_player(cell):
		return false
	move_cooldown = 0.35
	_record("move", [cell.x, cell.y])
	return true

func dismantle() -> bool:
	if outcome != "" or int(anchors.get(player_pos, 0)) <= 0 or energy < 2:
		return false
	energy -= 2
	anchors[player_pos] -= 1
	_record("anchor")
	if anchors[player_pos] == 0:
		broadcast = maxi(0, broadcast - 2)
		enemy_max_toughness = maxi(2, 6 - cleared())
		enemy_toughness = mini(enemy_toughness, enemy_max_toughness)
	if cleared() == 4:
		outcome = "victory"
		finish_reason = "ritual"
	after_action()
	return true

func use_card(index: int, target: Vector2i) -> bool:
	if not play_card(index, target, enemy_order[0]):
		return false
	if not replaying:
		journal.append({"kind": "card", "value": index, "target": [target.x, target.y]})
	after_action()
	return true

func after_action() -> void:
	broadcast = maxi(0, broadcast - host_fight.relief_pending)
	host_fight.relief_pending = 0
	host_fight.update_phase(self, cleared())
	if outcome != "" and finish_reason.is_empty():
		finish_reason = "kill" if outcome == "victory" else "hp"

func pulse() -> Array[Dictionary]:
	if outcome != "":
		return []
	_record("pulse")
	var turn_events: Array[Dictionary] = enemy_turn()
	after_action()
	if outcome == "":
		broadcast += 2 + (1 if player_pos in host_fight.camera_cells else 0)
		if broadcast >= broadcast_max:
			outcome = "defeat"
			finish_reason = "broadcast"
	if outcome == "":
		start_player_turn()
		host_fight.prepare(self)
	move_cooldown = 0.0
	return turn_events

func tick(delta: float) -> bool:
	# The overworld finale is fully turn-based. This method only keeps the
	# presentation cooldown responsive; it never advances a Boss turn.
	move_cooldown = maxf(0.0, move_cooldown - delta)
	return false

func cleared() -> int:
	var count := 0
	for hp in anchors.values():
		if int(hp) == 0:
			count += 1
	return count

func has_room_instance(instance_id: String) -> bool:
	return room_instances.has(instance_id)

func snapshot() -> Dictionary:
	return {"initial": initial.duplicate(true), "journal": journal.duplicate(true), "elapsed": free_elapsed, "cooldown": move_cooldown}

func replay(data: Dictionary) -> void:
	replaying = true
	for entry: Dictionary in data.get("journal", []):
		move_cooldown = 0.0
		match str(entry.get("kind", "")):
			"move":
				var value: Variant = entry.get("value", [0, 0])
				var cell := Vector2i(int(value[0]), int(value[1])) if value is Array else Vector2i(int(value), int(player_pos.y))
				step_to(cell)
			"anchor":
				dismantle()
			"card":
				var target_value: Variant = entry.get("target", [player_pos.x, player_pos.y])
				var target := Vector2i(int(target_value[0]), int(target_value[1])) if target_value is Array else Vector2i(int(target_value), int(player_pos.y))
				use_card(int(entry.get("value", -1)), target)
			"hide":
				# Legacy journals may contain this removed action.
				energy = maxi(0, energy - 1)
			"pulse":
				pulse()
	journal = data.get("journal", []).duplicate(true)
	free_elapsed = float(data.get("elapsed", 0.0))
	move_cooldown = float(data.get("cooldown", 0.0))
	replaying = false
