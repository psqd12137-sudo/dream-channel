extends RefCounted

## Persist discoveries on room instances, without consuming the run RNG.
static func discover(rooms, run_length: int) -> int:
	var records: Array[Dictionary] = []
	var seen := {}
	for cell: Vector2i in rooms.placed:
		var room: Dictionary = rooms.placed[cell]
		var id := str(room.get("instance_id", ""))
		if seen.has(id) or not bool(room.get("completed", false)):
			continue
		seen[id] = true
		if int(room.get("completion_order", 0)) > 0:
			records.append({"cell": cell, "room": room})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.room.completion_order) < int(b.room.completion_order))
	var added := 0
	var total := maxi(4, run_length - 1)
	var previous := 0
	for fraction: float in [0.18, 0.36, 0.63, 0.81]:
		var threshold := maxi(previous + 1, int(ceil(total * fraction)))
		previous = threshold
		for record: Dictionary in records:
			if int(record.room.completion_order) < threshold:
				continue
			# Completion orders are unique; a threshold always names one room.
			if not record.room.has("signal_anchor_cell"):
				var cells: Array = record.room.get("world_cells", [[record.cell.x, record.cell.y]]).duplicate(true)
				cells.sort_custom(func(a: Array, b: Array) -> bool:
					return int(a[1]) < int(b[1]) or int(a[1]) == int(b[1]) and int(a[0]) < int(b[0]))
				rooms.set_instance_flag(record.cell, "signal_anchor_cell", cells[0])
				added += 1
			break
	return added

static func cells(rooms) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for room: Dictionary in rooms.placed.values():
		var raw: Array = room.get("signal_anchor_cell", [])
		if raw.size() != 2 or not bool(room.get("completed", false)):
			continue
		var cell := Vector2i(int(raw[0]), int(raw[1]))
		if rooms.placed.has(cell) and cell not in result:
			result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	return result
