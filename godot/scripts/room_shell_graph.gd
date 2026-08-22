class_name RoomShellGraph
extends RefCounted

## Semantic wall graph for Tiny-Glade-like intent editing.
## The editor still uses 1/3/5 room footprints, but walls are grouped into
## continuous runs so the renderer can join them without treating every
## segment as an unrelated prop.

const Rules = preload("res://scripts/asset_diorama_rules.gd")


static func compile(room_cells: Array[Vector2i], raw_walls: Array) -> Dictionary:
	var walls: Array[Dictionary] = []
	for raw_wall: Variant in raw_walls:
		if not raw_wall is Dictionary:
			continue
		var normalized := normalize_wall(raw_wall)
		if normalized.is_empty():
			continue
		walls.append(normalized)
	var runs: Array[Dictionary] = []
	var run_by_key := {}
	var run_counter := 0
	for index in walls.size():
		var wall := walls[index]
		var line_key := _line_key(wall)
		var kind_family := _kind_family(str(wall.get("kind", "cb_wall")))
		var group_key := "%s|%s" % [line_key, kind_family]
		var matching_run: Dictionary = {}
		for candidate: Dictionary in runs:
			if str(candidate.get("group_key", "")) != group_key:
				continue
			if _run_can_join(candidate, wall):
				matching_run = candidate
				break
		if matching_run.is_empty():
			matching_run = {
				"run_id": "run_%03d" % run_counter,
				"group_key": group_key,
				"axis": wall.get("axis", Vector3i.ZERO),
				"line": wall.get("line", 0),
				"wall_indices": [],
				"start": wall.get("start", Vector3.ZERO),
				"end": wall.get("end", Vector3.ZERO),
				"has_doorway": false,
			}
			run_counter += 1
			runs.append(matching_run)
		matching_run["wall_indices"].append(index)
		matching_run["start"] = _min_endpoint(matching_run.get("start", wall.get("start", Vector3.ZERO)), wall.get("start", Vector3.ZERO), wall.get("axis", Vector3i.ZERO))
		matching_run["end"] = _max_endpoint(matching_run.get("end", wall.get("end", Vector3.ZERO)), wall.get("end", Vector3.ZERO), wall.get("axis", Vector3i.ZERO))
		matching_run["has_doorway"] = bool(matching_run.get("has_doorway", false)) or str(wall.get("kind", "")) == "cb_doorway"
		wall["run_id"] = matching_run.get("run_id", "")
		walls[index] = wall
	var joins: Array[Dictionary] = []
	for run: Dictionary in runs:
		var indices: Array = run.get("wall_indices", [])
		if indices.size() < 2:
			continue
		indices.sort_custom(func(a: Variant, b: Variant): return _along_value(walls[int(a)]) < _along_value(walls[int(b)]))
		for offset in range(indices.size() - 1):
			var first := walls[int(indices[offset])]
			var second := walls[int(indices[offset + 1])]
			var first_end: Vector3 = first.get("end", Vector3.ZERO)
			var second_start: Vector3 = second.get("start", Vector3.ZERO)
			if first_end.distance_to(second_start) <= Rules.CELL * 0.08 or _segment_gap(first, second) <= Rules.CELL * 0.08:
				joins.append({
					"run_id": run.get("run_id", ""),
					"position": (first_end + second_start) * 0.5,
					"axis": first.get("axis", Vector3i.ZERO),
					"color_index": 0,
				})
	var sockets := boundary_sockets(room_cells)
	return {"walls": walls, "runs": runs, "joins": joins, "boundary_sockets": sockets}


static func normalize_wall(raw_wall: Dictionary) -> Dictionary:
	var position := _vec3(raw_wall.get("position", []))
	var axis := _vec3i(raw_wall.get("wall_axis", raw_wall.get("axis", [])))
	if axis == Vector3i.ZERO:
		return {}
	var kind := Rules.normalize_wall_kind(str(raw_wall.get("wall_kind", raw_wall.get("kind", "cb_wall"))))
	var axis_vector := Vector3(axis.x, 0.0, axis.z).normalized()
	var start := _vec3(raw_wall.get("wall_start", [])) if raw_wall.has("wall_start") else position - axis_vector * Rules.CELL * 0.5
	var end := _vec3(raw_wall.get("wall_end", [])) if raw_wall.has("wall_end") else position + axis_vector * Rules.CELL * 0.5
	return {
		"kind": kind,
		"position": position,
		"yaw": float(raw_wall.get("yaw", 0.0)),
		"axis": axis,
		"cell": _vec2i(raw_wall.get("wall_cell", raw_wall.get("cell", []))),
		"start": start,
		"end": end,
		"line": roundi(position.z if axis.x != 0 else position.x),
		"run_id": str(raw_wall.get("run_id", "")),
		"is_door": bool(raw_wall.get("is_door", kind == "cb_doorway")),
		"door_restore_kind": str(raw_wall.get("door_restore_kind", "cb_wall")),
	}


static func replace_wall_with_door(wall: Dictionary) -> Dictionary:
	var result := wall.duplicate(true)
	result["kind"] = "cb_doorway"
	result["wall_kind"] = "cb_doorway"
	result["is_door"] = true
	result["door_restore_kind"] = Rules.normalize_wall_kind(str(wall.get("kind", wall.get("wall_kind", "cb_wall"))))
	result["door_restore_start"] = wall.get("wall_start", wall.get("start", []))
	result["door_restore_end"] = wall.get("wall_end", wall.get("end", []))
	return result


static func restore_door(door: Dictionary) -> Dictionary:
	var result := door.duplicate(true)
	result["kind"] = Rules.normalize_wall_kind(str(door.get("door_restore_kind", "cb_wall")))
	result["wall_kind"] = result["kind"]
	result.erase("is_door")
	result.erase("door_restore_kind")
	result.erase("door_restore_start")
	result.erase("door_restore_end")
	return result


static func boundary_sockets(room_cells: Array[Vector2i]) -> Array[Dictionary]:
	var sockets: Array[Dictionary] = []
	for edge in Rules.room_boundary_edges(room_cells):
		var start: Vector3 = edge.get("start", Vector3.ZERO)
		var finish: Vector3 = edge.get("end", Vector3.ZERO)
		var axis: Vector3i = edge.get("axis", Vector3i.ZERO)
		sockets.append({
			"socket_id": _edge_key(start, finish),
			"start": start,
			"end": finish,
			"midpoint": (start + finish) * 0.5,
			"axis": axis,
			"room_cell": edge.get("cell", Vector2i.ZERO),
			"occupied": false,
		})
	return sockets


static func shared_boundary_connections(first_cells: Array[Vector2i], second_cells: Array[Vector2i]) -> Array[Dictionary]:
	var first_edges := boundary_sockets(first_cells)
	var second_edges := boundary_sockets(second_cells)
	var result: Array[Dictionary] = []
	for first: Dictionary in first_edges:
		for second: Dictionary in second_edges:
			var same_axis: bool = first.get("axis", Vector3i.ZERO) == second.get("axis", Vector3i.ZERO)
			var direct: bool = first.get("start", Vector3.ZERO).is_equal_approx(second.get("end", Vector3.ZERO)) and first.get("end", Vector3.ZERO).is_equal_approx(second.get("start", Vector3.ZERO))
			if same_axis and direct:
				result.append({
					"first_socket": first.get("socket_id", ""),
					"second_socket": second.get("socket_id", ""),
					"midpoint": first.get("midpoint", Vector3.ZERO),
					"axis": first.get("axis", Vector3i.ZERO),
					"kind": "room_connector",
				})
	return result


static func _run_can_join(run: Dictionary, wall: Dictionary) -> bool:
	if run.get("axis", Vector3i.ZERO) != wall.get("axis", Vector3i.ZERO):
		return false
	if int(run.get("line", 0)) != int(wall.get("line", 0)):
		return false
	var start: Vector3 = run.get("start", Vector3.ZERO)
	var finish: Vector3 = run.get("end", Vector3.ZERO)
	var candidate_start: Vector3 = wall.get("start", Vector3.ZERO)
	var candidate_end: Vector3 = wall.get("end", Vector3.ZERO)
	return _segment_gap_between(start, finish, candidate_start, candidate_end) <= Rules.CELL * 1.05


static func _segment_gap(wall_a: Dictionary, wall_b: Dictionary) -> float:
	return _segment_gap_between(wall_a.get("start", Vector3.ZERO), wall_a.get("end", Vector3.ZERO), wall_b.get("start", Vector3.ZERO), wall_b.get("end", Vector3.ZERO))


static func _segment_gap_between(start_a: Vector3, end_a: Vector3, start_b: Vector3, end_b: Vector3) -> float:
	return minf(minf(start_a.distance_to(start_b), start_a.distance_to(end_b)), minf(end_a.distance_to(start_b), end_a.distance_to(end_b)))


static func _along_value(wall: Dictionary) -> float:
	var position: Vector3 = wall.get("position", Vector3.ZERO)
	var axis: Vector3i = wall.get("axis", Vector3i.ZERO)
	return position.x if axis.x != 0 else position.z


static func _min_endpoint(first: Vector3, second: Vector3, axis: Vector3i) -> Vector3:
	return first if _along_value({"position": first, "axis": axis}) <= _along_value({"position": second, "axis": axis}) else second


static func _max_endpoint(first: Vector3, second: Vector3, axis: Vector3i) -> Vector3:
	return first if _along_value({"position": first, "axis": axis}) >= _along_value({"position": second, "axis": axis}) else second


static func _kind_family(kind: String) -> String:
	return "doorway" if kind == "cb_doorway" else "wall"


static func _line_key(wall: Dictionary) -> String:
	var axis: Vector3i = wall.get("axis", Vector3i.ZERO)
	return "x:%d" % int(wall.get("line", 0)) if axis.x != 0 else "z:%d" % int(wall.get("line", 0))


static func _edge_key(start: Vector3, finish: Vector3) -> String:
	var a := "%d,%d" % [roundi(start.x * 100.0), roundi(start.z * 100.0)]
	var b := "%d,%d" % [roundi(finish.x * 100.0), roundi(finish.z * 100.0)]
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


static func _vec3(value: Variant) -> Vector3:
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2])) if values.size() >= 3 else Vector3.ZERO


static func _vec3i(value: Variant) -> Vector3i:
	var values := value as Array
	return Vector3i(int(values[0]), int(values[1]), int(values[2])) if values.size() >= 3 else Vector3i.ZERO


static func _vec2i(value: Variant) -> Vector2i:
	var values := value as Array
	return Vector2i(int(values[0]), int(values[1])) if values.size() >= 2 else Vector2i.ZERO
