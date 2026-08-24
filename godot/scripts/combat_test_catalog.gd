class_name CombatTestCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/test_mode/combat_ai_scenarios.json"
const VALID_CATEGORIES := ["combat", "ai", "multi_enemy", "presentation"]
const VALID_ROLES := ["auto", "hunter", "flanker", "controller"]
const VALID_PLAYER_SCRIPTS := ["stationary", "alternate_cells", "safe_random_walk"]

var scenarios: Array[Dictionary] = []
var errors: Array[String] = []


func load_from_path(path: String = DEFAULT_PATH) -> bool:
	scenarios.clear()
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append("测试目录不存在：%s" % path)
		return false
	var raw_text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		errors.append("测试目录必须是 JSON 对象")
		return false
	var raw_scenarios: Variant = (parsed as Dictionary).get("scenarios", [])
	if not raw_scenarios is Array or (raw_scenarios as Array).is_empty():
		errors.append("测试目录至少需要一个 scenarios 条目")
		return false
	var used_ids: Dictionary = {}
	for index in range((raw_scenarios as Array).size()):
		var raw: Variant = (raw_scenarios as Array)[index]
		if not raw is Dictionary:
			errors.append("scenarios[%d] 必须是对象" % index)
			continue
		var scenario := (raw as Dictionary).duplicate(true)
		var scenario_errors := _validate_scenario(scenario, index, used_ids)
		if scenario_errors.is_empty():
			scenarios.append(scenario)
			used_ids[str(scenario["id"])] = true
		else:
			errors.append_array(scenario_errors)
	return errors.is_empty() and not scenarios.is_empty()


func ids() -> Array[String]:
	var result: Array[String] = []
	for scenario in scenarios:
		result.append(str(scenario.get("id", "")))
	return result


func get_scenario(scenario_id: String) -> Dictionary:
	for scenario in scenarios:
		if str(scenario.get("id", "")) == scenario_id:
			return scenario.duplicate(true)
	return {}


func first_id() -> String:
	return str(scenarios[0].get("id", "")) if not scenarios.is_empty() else ""


func _validate_scenario(scenario: Dictionary, index: int, used_ids: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var prefix := "scenarios[%d]" % index
	var scenario_id := str(scenario.get("id", "")).strip_edges()
	if scenario_id.is_empty():
		result.append("%s.id 不能为空" % prefix)
	elif used_ids.has(scenario_id):
		result.append("%s.id 重复：%s" % [prefix, scenario_id])
	var category := str(scenario.get("category", ""))
	if category not in VALID_CATEGORIES:
		result.append("%s.category 无效：%s" % [prefix, category])
	var room: Variant = scenario.get("room", {})
	if not room is Dictionary:
		result.append("%s.room 必须是对象" % prefix)
		return result
	var arena: Variant = (room as Dictionary).get("arena", {})
	if not arena is Dictionary:
		result.append("%s.room.arena 必须是对象" % prefix)
		return result
	var cols := int((arena as Dictionary).get("cols", 0))
	var rows := int((arena as Dictionary).get("rows", 0))
	if cols <= 0 or rows <= 0:
		result.append("%s.room.arena 必须有正数 cols/rows" % prefix)
	var walls := _parse_cells((arena as Dictionary).get("walls", []))
	var used_cells: Dictionary = {}
	for raw_enemy in (room as Dictionary).get("enemies", []):
		if not raw_enemy is Dictionary:
			result.append("%s.room.enemies 必须全部是对象" % prefix)
			continue
		var enemy: Dictionary = raw_enemy
		var enemy_id := str(enemy.get("id", "")).strip_edges()
		var spawn := _parse_cell(enemy.get("spawn", []))
		if enemy_id.is_empty():
			result.append("%s 敌人缺少 id" % prefix)
		if spawn.x < 0 or spawn.x >= cols or spawn.y < 0 or spawn.y >= rows:
			result.append("%s 敌人 %s 出生点越界" % [prefix, enemy_id])
		if walls.has(spawn):
			result.append("%s 敌人 %s 出生在墙内" % [prefix, enemy_id])
		if used_cells.has(spawn):
			result.append("%s 敌人 %s 与 %s 出生点重叠" % [prefix, enemy_id, str(used_cells[spawn])])
		used_cells[spawn] = enemy_id
		var role := str(enemy.get("behavior_role", "auto"))
		if role not in VALID_ROLES:
			result.append("%s 敌人 %s behavior_role 无效：%s" % [prefix, enemy_id, role])
	var observer: Variant = scenario.get("observer", {})
	if not observer is Dictionary:
		result.append("%s.observer 必须是对象" % prefix)
	else:
		var player_script := str((observer as Dictionary).get("player_script", "stationary"))
		if player_script not in VALID_PLAYER_SCRIPTS:
			result.append("%s.observer.player_script 无效：%s" % [prefix, player_script])
		if int((observer as Dictionary).get("max_rounds", 0)) <= 0:
			result.append("%s.observer.max_rounds 必须为正数" % prefix)
	return result


func _parse_cells(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Array:
		return result
	for cell in raw as Array:
		var parsed := _parse_cell(cell)
		if parsed != Vector2i(-999, -999):
			result[parsed] = true
	return result


func _parse_cell(raw: Variant) -> Vector2i:
	if raw is Vector2i:
		return raw
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	if raw is String:
		var parts := (raw as String).split(",", false)
		if parts.size() >= 2:
			return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(-999, -999)
