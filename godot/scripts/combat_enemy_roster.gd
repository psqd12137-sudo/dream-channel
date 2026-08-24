extends RefCounted

# 多敌人内容标准化模块（multi-enemy refactor plan 3.2）。
# 只在加载边界调用：把旧房间格式（room.enemy + arena.enemy）与新格式
# （room.enemies[]）统一转换为标准敌人数组，并完成 ID 与出生点校验。
# 输出 spec 使用 Godot 运行时坐标（[x, y] 数组）；数据源是 Web 坐标时，
# 调用方（web_content_adapter）必须先完成翻转。

const CombatEnemyState = preload("res://scripts/combat_enemy_state.gd")


static func normalize(room: Dictionary, arena: Dictionary) -> Dictionary:
	var cols := int(arena.get("cols", 5))
	var rows := int(arena.get("rows", 3))
	var walls := _collect_walls(arena.get("walls", []))
	var room_id := str(room.get("id", room.get("instance_id", "room")))
	var raw_specs: Array = []
	var using_legacy := false
	var declared: Array = room.get("enemies", []) if room.has("enemies") else []
	if not declared.is_empty():
		for raw in declared:
			raw_specs.append(raw)
	elif room.has("enemy") or arena.has("enemy"):
		using_legacy = true
		raw_specs.append(room.get("enemy", {}))

	var errors: Array[String] = []
	var specs: Array = []
	var order: Array[String] = []
	var used_ids: Dictionary = {}
	var used_cells: Dictionary = {}
	var legacy_spawn := _parse_spawn(arena.get("enemy", [cols - 1, 1]))

	for index in range(raw_specs.size()):
		var raw: Variant = raw_specs[index]
		if not raw is Dictionary:
			errors.append("enemy index %d must be a dictionary, got %s" % [index, typeof(raw)])
			continue
		var source: Dictionary = raw
		var spec: Dictionary = source.duplicate(true)
		var enemy_id := str(spec.get("id", ""))
		if enemy_id == "" and using_legacy:
			enemy_id = "%s_enemy" % room_id
		if enemy_id == "":
			enemy_id = "%s_enemy_%d" % [room_id, index]
		spec["id"] = enemy_id
		var spawn_raw: Variant = spec.get("spawn", legacy_spawn if using_legacy else null)
		if spawn_raw == null:
			errors.append("enemy '%s' index %d is missing required spawn" % [enemy_id, index])
			continue
		var spawn := _parse_spawn(spawn_raw)
		spec["spawn"] = [spawn.x, spawn.y]
		if used_ids.has(enemy_id):
			errors.append("duplicate enemy id '%s' at index %d" % [enemy_id, index])
			continue
		if spawn.x < 0 or spawn.x >= cols or spawn.y < 0 or spawn.y >= rows:
			errors.append("enemy '%s' spawn (%d, %d) is out of arena bounds cols=%d rows=%d" % [enemy_id, spawn.x, spawn.y, cols, rows])
			continue
		if walls.has(spawn):
			errors.append("enemy '%s' spawn (%d, %d) is inside a wall cell" % [enemy_id, spawn.x, spawn.y])
			continue
		if used_cells.has(spawn):
			errors.append("enemy '%s' spawn (%d, %d) overlaps enemy '%s'" % [enemy_id, spawn.x, spawn.y, str(used_cells[spawn])])
			continue
		used_ids[enemy_id] = true
		used_cells[spawn] = enemy_id
		_fill_defaults(spec, arena)
		specs.append(spec)
		order.append(enemy_id)

	if errors.is_empty():
		return {"ok": true, "enemies": specs, "order": order, "legacy": using_legacy}
	return {"ok": false, "enemies": [], "order": [], "legacy": using_legacy, "errors": errors}


static func build_states(specs: Array) -> Array:
	var states: Array = []
	for index in range(specs.size()):
		states.append(build_state(specs[index], index))
	return states


static func build_state(spec: Dictionary, spawn_order: int) -> RefCounted:
	var state: RefCounted = CombatEnemyState.new()
	state.id = str(spec.get("id", ""))
	state.spawn_order = spawn_order
	var spawn := _parse_spawn(spec.get("spawn", [0, 0]))
	state.pos = spawn
	state.max_hp = maxi(1, int(spec.get("hp", 6)))
	state.hp = state.max_hp
	state.max_toughness = maxi(0, int(spec.get("toughness", 3)))
	state.toughness = state.max_toughness
	state.damage = int(spec.get("damage", 1))
	state.action_points = int(spec.get("action_points", 3))
	state.attack_cost = int(spec.get("attack_cost", 2))
	state.name = str(spec.get("name", "雪花剪影"))
	state.tier = int(spec.get("tier", 1))
	state.archetype = str(spec.get("archetype", "execute"))
	state.archetype_label = str(spec.get("archetype_label", state.archetype))
	state.archetype_desc = str(spec.get("archetype_desc", ""))
	var traits: Array[String] = []
	for raw_trait in spec.get("traits", []):
		traits.append(str(raw_trait))
	state.traits = traits
	state.trait_labels = (spec.get("trait_labels", {}) as Dictionary).duplicate(true)
	var ambush := bool(spec.get("ambush", false))
	state.ambush_active = ambush
	state.revealed = not ambush
	state.player_sees_enemy = not ambush
	state.sees_player = not ambush
	return state


static func _fill_defaults(spec: Dictionary, arena: Dictionary) -> void:
	if not spec.has("name"):
		spec["name"] = "雪花剪影"
	if not spec.has("hp"):
		spec["hp"] = 6
	if not spec.has("damage"):
		spec["damage"] = 1
	if not spec.has("toughness"):
		spec["toughness"] = 3
	if not spec.has("action_points"):
		spec["action_points"] = 3
	if not spec.has("attack_cost"):
		spec["attack_cost"] = 2
	if not spec.has("tier"):
		spec["tier"] = 1
	if not spec.has("archetype"):
		spec["archetype"] = "execute"
	if not spec.has("archetype_label"):
		spec["archetype_label"] = spec["archetype"]
	if not spec.has("archetype_desc"):
		spec["archetype_desc"] = ""
	if not spec.has("traits"):
		spec["traits"] = []
	if not spec.has("trait_labels"):
		spec["trait_labels"] = {}
	if not spec.has("ambush"):
		spec["ambush"] = bool(arena.get("ambush", false))


static func _collect_walls(raw_walls: Array) -> Dictionary:
	var result := {}
	for raw in raw_walls:
		var cell := _parse_spawn(raw)
		if cell != Vector2i(-999, -999):
			result[cell] = true
	return result


static func _parse_spawn(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	if raw is String:
		var parts: PackedStringArray = (raw as String).split(",", false)
		if parts.size() >= 2:
			return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return Vector2i(-999, -999)
