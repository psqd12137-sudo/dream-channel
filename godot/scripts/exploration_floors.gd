extends RefCounted

static func ensure_sites(rooms) -> void:
	var ground: Array[Dictionary] = []
	var seen := {}
	var assigned := {}
	for cell: Vector2i in rooms.placed:
		var room: Dictionary = rooms.placed[cell]
		if room.has("stair_destination_floor"):
			assigned[int(room.stair_destination_floor)] = true
		var id := str(room.get("instance_id", ""))
		if seen.has(id) or int(room.get("floor", 0)) != 0 or not bool(room.get("completed", false)):
			continue
		seen[id] = true
		if int(room.get("completion_order", 0)) > 0:
			ground.append({"cell": cell, "room": room})
	ground.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.room.completion_order) < int(b.room.completion_order))
	for floor_index: int in [1, -1]:
		if assigned.has(floor_index):
			continue
		for record: Dictionary in ground:
			if int(record.room.completion_order) < (2 if floor_index == 1 else 5) or record.room.has("stair_destination_floor"):
				continue
			rooms.set_instance_flag(record.cell, "stair_destination_floor", floor_index)
			rooms.set_instance_flag(record.cell, "stair_entry_cell", [record.cell.x, record.cell.y])
			break

static func action(rooms, cell: Vector2i) -> Dictionary:
	var neighbors: Array[Vector2i] = rooms.stair_neighbors(cell)
	if not neighbors.is_empty():
		var target := neighbors[0]
		return {"target": target, "label": "前往" + str(rooms.placed[target].get("floor_label", "地面层")), "build": false}
	var room: Dictionary = rooms.placed.get(cell, {})
	var raw: Array = room.get("stair_entry_cell", [])
	if raw.size() != 2 or Vector2i(int(raw[0]), int(raw[1])) != cell:
		return {}
	var floor_index := int(room.get("stair_destination_floor", 0))
	# Separate logical floors without inflating shared rectangular board bounds.
	var origin := Vector2i(0, floor_index * 256)
	return {"target": origin, "source": cell, "floor": floor_index, "floor_origin": [origin.x, origin.y], "floor_height": floor_index * 5.0, "floor_label": "二楼" if floor_index == 1 else "地下室", "label": "扩建二楼入口" if floor_index == 1 else "扩建地下室入口", "build": true}
