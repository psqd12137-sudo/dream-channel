extends RefCounted

const SHAPES := {
	"single": [[0, 0]],
	"line3": [[0, 0], [1, 0], [2, 0]],
	"l3": [[0, 0], [1, 0], [0, 1]],
	"plus5": [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]],
	"t5": [[0, 0], [-1, 0], [1, 0], [0, 1], [0, 2]],
	"p5": [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2]],
	"stair5": [[0, 0], [1, 0], [1, 1], [2, 1], [2, 2]],
	"u5": [[0, 0], [1, 0], [2, 0], [0, 1], [2, 1]],
}

# Geometry and pacing are deliberately separate. A single-cell room may still
# be an empty beat, a recovery beat, or a light skirmish without changing shape.
const ROOM_CONFIG := {
	"foyer": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"porch": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"living": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"kitchen": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"pantry": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"yard": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"shed": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"guest": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"greenhouse": {"shape": "single", "tier": "beat", "pace_role": "empty"},
	"bedroom": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"nursery": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"darkroom": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"attic": {"shape": "single", "tier": "beat", "pace_role": "skirmish"},
	"ritual": {"shape": "single", "tier": "beat", "pace_role": "recovery"},
	"mudroom": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"west_wing": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"parlor": {"shape": "l3", "tier": "minigame", "pace_role": "puzzle"},
	"gallery": {"shape": "l3", "tier": "minigame", "pace_role": "capture"},
	"loft": {"shape": "line3", "tier": "minigame", "pace_role": "chase"},
	"hall": {"shape": "plus5", "tier": "elite", "pace_role": "elite_combat"},
	"study": {"shape": "t5", "tier": "elite", "pace_role": "elite_combat"},
	"cellar": {"shape": "p5", "tier": "elite", "pace_role": "elite_combat"},
	"boiler": {"shape": "stair5", "tier": "elite", "pace_role": "elite_combat"},
	"altar": {"shape": "u5", "tier": "elite", "pace_role": "elite_combat"},
}


static func apply_to_room(room: Dictionary, room_id: String) -> void:
	var config: Dictionary = ROOM_CONFIG.get(room_id, {"shape": "single", "tier": "beat", "pace_role": "empty"})
	var shape_id := str(config.get("shape", "single"))
	room["footprint_kind"] = shape_id
	room["footprint"] = (SHAPES.get(shape_id, SHAPES["single"]) as Array).duplicate(true)
	room["room_size"] = (room["footprint"] as Array).size()
	room["encounter_tier"] = str(config.get("tier", "beat"))
	room["pace_role"] = str(config.get("pace_role", "empty"))
	expand_large_arena(room)


static func expand_large_arena(room: Dictionary) -> void:
	if int(room.get("room_size", 1)) != 5 or not room.has("arena"):
		return
	var arena: Dictionary = room["arena"]
	if int(arena.get("footprint_grid_version", 0)) >= 1:
		return
	var cells: Array = room.get("footprint", [])
	if cells.is_empty():
		return
	var low := Vector2i(9999, 9999)
	var high := Vector2i(-9999, -9999)
	for raw: Array in cells:
		low = low.min(Vector2i(int(raw[0]), int(raw[1])))
		high = high.max(Vector2i(int(raw[0]), int(raw[1])))
	var old_size := Vector2i(int(arena.get("cols", 5)), int(arena.get("rows", 3)))
	var new_size := (high - low + Vector2i.ONE) * 3
	for key: String in ["player", "enemy"]:
		if arena.has(key):
			arena[key] = _rescale_arena_position(arena[key], old_size, new_size)
	var walls: Array = []
	for raw: String in arena.get("walls", []):
		var key := _rescale_arena_key(raw, old_size, new_size)
		if key not in walls:
			walls.append(key)
	arena["walls"] = walls
	var heights := {}
	for raw: String in arena.get("heights", {}):
		heights[_rescale_arena_key(raw, old_size, new_size)] = arena["heights"][raw]
	arena["heights"] = heights
	var portals: Array = []
	for pair: Array in arena.get("portals", []):
		portals.append([_rescale_arena_key(str(pair[0]), old_size, new_size), _rescale_arena_key(str(pair[1]), old_size, new_size)])
	arena["portals"] = portals
	var anchors: Array = []
	for raw: String in arena.get("anchors", []):
		anchors.append(_rescale_arena_key(raw, old_size, new_size))
	arena["anchors"] = anchors
	for enemy: Dictionary in room.get("enemies", []):
		if enemy.has("spawn"):
			enemy["spawn"] = _rescale_arena_position(enemy["spawn"], old_size, new_size)
	arena["cols"] = new_size.x
	arena["rows"] = new_size.y
	arena["footprint_grid_version"] = 1


static func _rescale_arena_position(raw: Array, old_size: Vector2i, new_size: Vector2i) -> Array:
	return [clampi(floori((float(raw[0]) + 0.5) * new_size.x / old_size.x), 0, new_size.x - 1), clampi(floori((float(raw[1]) + 0.5) * new_size.y / old_size.y), 0, new_size.y - 1)]


static func _rescale_arena_key(raw: String, old_size: Vector2i, new_size: Vector2i) -> String:
	var parts := raw.split(",")
	var cell := _rescale_arena_position([int(parts[0]), int(parts[1])], old_size, new_size)
	return "%d,%d" % [cell[0], cell[1]]
