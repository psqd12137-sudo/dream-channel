extends RefCounted

const SNAPSHOT_ROOT := "res://data/exe_snapshot/"
const SOURCE_ID := "CabinSlice_织梦频道.exe@EEC4C574CC22"

var snapshot_root := SNAPSHOT_ROOT
var source_id := SOURCE_ID


func _init(custom_root: String = SNAPSHOT_ROOT, custom_source_id: String = SOURCE_ID) -> void:
	snapshot_root = custom_root
	if not snapshot_root.ends_with("/"):
		snapshot_root += "/"
	source_id = custom_source_id


func build_content(run_seed: int) -> Dictionary:
	var rooms_json := _load_json("rooms.json")
	var cards_json := _load_json("cards.json")
	var relics_json := _load_json("relics.json")
	var pressure_json := _load_json("pressure.json")
	var bosses_json := _load_json("bosses.json")
	if rooms_json.is_empty() or cards_json.is_empty():
		return {}

	var layout: Dictionary = rooms_json.get("layoutRoll", {})
	var patterns: Array = layout.get("doorPatterns", [])
	var excluded: Dictionary = {}
	for id in layout.get("exclude", []):
		excluded[str(id)] = true
	var start_id := str(rooms_json.get("startRoom", "foyer"))
	excluded[start_id] = true

	var room_catalog: Array = []
	var room_records: Dictionary = rooms_json.get("rooms", {})
	var index := 0
	var combat_index := 0
	for raw_id in room_records.keys():
		var id := str(raw_id)
		if excluded.has(id):
			continue
		var source: Dictionary = room_records[id]
		var kind := "combat" if bool(source.get("combat", false)) else "event" if source.has("eventType") else "quiet"
		var pattern: Dictionary = patterns[posmod(id.hash() + run_seed + index, patterns.size())] if not patterns.is_empty() else {}
		var arena := _normalize_arena(source.get("arena", rooms_json.get("defaultArena", {})))
		var enemy: Dictionary = source.get("enemy", {}).duplicate(true)
		if enemy.is_empty():
			enemy = {"name": "雪花剪影", "hp": 6, "damage": 1}
		enemy["id"] = "%s_enemy" % id
		if kind == "combat":
			combat_index += 1
			enemy = _scale_enemy(enemy, id, combat_index, pressure_json)
		else:
			enemy["toughness"] = int(enemy.get("toughness", 3))
			enemy["action_points"] = int(enemy.get("action_points", 3))
			enemy["attack_cost"] = int(enemy.get("attack_cost", 2))
		room_catalog.append({
			"id": id,
			"name": str(source.get("name", id)),
			"description": str(source.get("desc", "")),
			"kind": kind,
			"event_type": str(source.get("eventType", "")),
			"doors": _pattern_doors(pattern.get("doors", {})),
			"door_pattern": str(pattern.get("id", "?")),
			"arena": arena,
			"enemy": enemy,
		})
		index += 1

	var start_source: Dictionary = room_records.get(start_id, {})
	var start_room := {
		"id": start_id,
		"name": str(start_source.get("name", "玄关")),
		"description": str(start_source.get("desc", "")),
		"kind": "quiet",
		"doors": [true, true, true, true],
	}

	var relic_pool: Array = relics_json.get("pool", [])
	var active_relics: Array = []
	if not relic_pool.is_empty():
		active_relics.append(str(relic_pool[0]))

	return {
		"schema_version": 2,
		"source_commit": source_id,
		"source_room_count": room_records.size(),
		"run_seed": run_seed,
		"run_length": int(rooms_json.get("runLength", 12)),
		"start_room": start_room,
		"rooms": room_catalog,
		"cards": cards_json.get("cards", {}),
		"starter_deck": cards_json.get("starter", []),
		"reward_pool": cards_json.get("rewardPool", []),
		"relics": relics_json.get("relics", {}),
		"relic_pool": relic_pool,
		"active_relics": active_relics,
		"pressure": pressure_json,
		"bosses": bosses_json,
		"run_rules": {
			"player_hp": 6,
			"base_speed": int(cards_json.get("baseSpeed", 3)),
			"hand_size": int(cards_json.get("handSize", 4)),
			"dice_faces": cards_json.get("diceFaces", [0, 1, 2]),
			"move_cost": int(cards_json.get("moveCost", 1)),
			"hostile_pass_cost": int(cards_json.get("hostilePassCost", 1)),
		},
	}


func _normalize_arena(raw_value: Variant) -> Dictionary:
	if not raw_value is Dictionary:
		return {}
	var raw: Dictionary = raw_value
	var result := raw.duplicate(true)
	# Web 数据坐标为 [row, col] / "row,col"；Godot 运行时统一使用 (x, y)。
	result["player"] = _flip_pair(raw.get("player", [1, 0]))
	result["enemy"] = _flip_pair(raw.get("enemy", [1, int(raw.get("cols", 5)) - 1]))
	var walls: Array = []
	for cell in raw.get("walls", []):
		walls.append(_flip_key(str(cell)))
	result["walls"] = walls
	var heights: Dictionary = {}
	for cell in raw.get("heights", {}).keys():
		heights[_flip_key(str(cell))] = int(raw["heights"][cell])
	result["heights"] = heights
	var portals: Array = []
	for pair in raw.get("portals", []):
		if pair is Array and pair.size() >= 2:
			portals.append([_flip_key(str(pair[0])), _flip_key(str(pair[1]))])
	result["portals"] = portals
	return result


func _scale_enemy(enemy: Dictionary, room_id: String, combat_index: int, pressure: Dictionary) -> Dictionary:
	var result := enemy.duplicate(true)
	var curve: Array = pressure.get("combatCurve", [1, 2, 2, 3, 3, 3])
	var tier := int(curve[mini(combat_index - 1, curve.size() - 1)]) if not curve.is_empty() else 1
	var scale: Dictionary = pressure.get("tierScale", {}).get(str(tier), {})
	var archetype_id := str(pressure.get("roomArchetype", {}).get(room_id, "execute"))
	var archetype: Dictionary = pressure.get("archetypes", {}).get(archetype_id, {})
	result["hp"] = int(result.get("hp", 6)) + int(scale.get("hp", 0))
	result["damage"] = int(result.get("damage", 1)) + int(scale.get("damage", 0))
	result["toughness"] = int(archetype.get("baseTough", 3)) + int(scale.get("tough", 0))
	result["action_points"] = 3 + int(scale.get("stam", 0))
	result["attack_cost"] = 2
	result["tier"] = tier
	result["archetype"] = archetype_id
	result["archetype_label"] = str(archetype.get("label", archetype_id))
	result["archetype_desc"] = str(archetype.get("desc", ""))
	return result


func _flip_pair(raw_value: Variant) -> Array:
	if raw_value is Array and raw_value.size() >= 2:
		return [int(raw_value[1]), int(raw_value[0])]
	return [0, 0]


func _flip_key(raw: String) -> String:
	var parts := raw.split(",")
	if parts.size() < 2:
		return raw
	return "%d,%d" % [int(parts[1]), int(parts[0])]


func _pattern_doors(raw: Dictionary) -> Array:
	return [
		bool(raw.get("N", false)),
		bool(raw.get("E", false)),
		bool(raw.get("S", false)),
		bool(raw.get("W", false)),
	]


func _load_json(file_name: String) -> Dictionary:
	var path := snapshot_root + file_name
	if not FileAccess.file_exists(path):
		push_error("Missing Web snapshot: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Invalid Web snapshot JSON: %s" % path)
		return {}
	return parsed
