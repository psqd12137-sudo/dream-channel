extends SceneTree

# 阶段 B：多敌人内容标准化与 EnemyState 工厂回归。

const CombatEnemyRoster = preload("res://scripts/combat_enemy_roster.gd")

const FLAG := "CHANNEL_MULTI_ENEMY_ROSTER"

var failures: Array[String] = []


func _init() -> void:
	_test_new_format_counts()
	_test_legacy_format()
	_test_generated_ids_deterministic()
	_test_validation_errors()
	_test_state_factory()
	if failures.is_empty():
		print("%s: PASS normalize legacy validation state-factory" % FLAG)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [FLAG, failure])
		print("%s: FAIL count=%d" % [FLAG, failures.size()])
		quit(1)


func _arena() -> Dictionary:
	return {
		"cols": 6,
		"rows": 3,
		"player": [0, 1],
		"enemy": [5, 1],
		"walls": ["0,2"],
		"heights": {},
		"portals": [],
	}


func _specs(count: int, with_ids := true) -> Array:
	var result: Array = []
	for i in range(count):
		var spec := {
			"spawn": [1 + (i % 5), int(floor(i / 5.0))],
			"name": "测试单位%d" % i,
			"hp": 4 + i,
			"damage": 1,
			"toughness": 2,
			"action_points": 2,
			"attack_cost": 2,
		}
		if with_ids:
			spec["id"] = "unit_%02d" % i
		result.append(spec)
	return result


func _test_new_format_counts() -> void:
	for n in [1, 2, 8]:
		var room := {"id": "lab", "enemies": _specs(n)}
		var result: Dictionary = CombatEnemyRoster.normalize(room, _arena())
		_check(bool(result["ok"]), "N=%d normalize must succeed, errors=%s" % [n, str(result.get("errors", []))])
		if not bool(result["ok"]):
			continue
		var enemies: Array = result["enemies"]
		var order: Array = result["order"]
		_check(enemies.size() == n, "N=%d must yield %d specs, got %d" % [n, n, enemies.size()])
		_check(order.size() == n, "N=%d order must hold %d ids" % [n, n])
		for i in range(n):
			var spec: Dictionary = enemies[i]
			_check(str(spec["id"]) == "unit_%02d" % i, "N=%d spec %d id mismatch: %s" % [n, i, str(spec["id"])])
			var spawn: Array = spec["spawn"]
			_check(spawn[0] == 1 + (i % 5) and spawn[1] == int(floor(i / 5.0)), "N=%d spec %d spawn mismatch: %s" % [n, i, str(spawn)])
			_check(int(spec["hp"]) == 4 + i, "N=%d spec %d hp mismatch" % [n, i])
			_check(str(spec["name"]) == "测试单位%d" % i, "N=%d spec %d name mismatch" % [n, i])


func _test_legacy_format() -> void:
	var room := {"id": "old_room", "enemy": {"id": "old_room_enemy", "name": "旧式剪影", "hp": 7}}
	var result: Dictionary = CombatEnemyRoster.normalize(room, _arena())
	_check(bool(result["ok"]), "legacy normalize must succeed")
	var enemies: Array = result["enemies"]
	_check(enemies.size() == 1, "legacy format must yield exactly 1 enemy, got %d" % enemies.size())
	_check(bool(result["legacy"]), "legacy marker must be set")
	if enemies.size() == 1:
		var spec: Dictionary = enemies[0]
		_check(str(spec["id"]) == "old_room_enemy", "legacy id must be preserved")
		var spawn: Array = spec["spawn"]
		_check(spawn[0] == 5 and spawn[1] == 1, "legacy spawn must come from arena.enemy, got %s" % str(spawn))
		_check(int(spec["hp"]) == 7, "legacy hp must be preserved")
	var missing_id := CombatEnemyRoster.normalize({"id": "gen_room", "enemy": {"hp": 5}}, _arena())
	_check(bool(missing_id["ok"]) and str((missing_id["enemies"] as Array)[0].get("id")) == "gen_room_enemy", "legacy enemy without id must get deterministic room id")


func _test_generated_ids_deterministic() -> void:
	var room := {"id": "seeded", "enemies": _specs(3, false)}
	var first: Dictionary = CombatEnemyRoster.normalize(room, _arena())
	var second: Dictionary = CombatEnemyRoster.normalize(room.duplicate(true), _arena().duplicate(true))
	_check(str(first["order"]) == str(second["order"]), "same input must produce identical order, got %s vs %s" % [str(first["order"]), str(second["order"])])
	var expected: Array = ["seeded_enemy_0", "seeded_enemy_1", "seeded_enemy_2"]
	_check(str(first["order"]) == str(expected), "generated ids must follow room+index pattern, got %s" % str(first["order"]))


func _test_validation_errors() -> void:
	var duplicate := {"id": "dup", "enemies": [
		{"id": "twin", "spawn": [1, 0], "hp": 5},
		{"id": "twin", "spawn": [2, 0], "hp": 5},
	]}
	var duplicate_result: Dictionary = CombatEnemyRoster.normalize(duplicate, _arena())
	_check(not bool(duplicate_result["ok"]), "duplicate id must fail")
	_check(_has_error(duplicate_result, "duplicate enemy id 'twin'"), "duplicate id error must be readable, got %s" % str(duplicate_result.get("errors", [])))

	var out_of_bounds := {"id": "oob", "enemies": [{"id": "far", "spawn": [9, 0], "hp": 5}]}
	var oob_result: Dictionary = CombatEnemyRoster.normalize(out_of_bounds, _arena())
	_check(not bool(oob_result["ok"]), "out-of-bounds spawn must fail")
	_check(_has_error(oob_result, "out of arena bounds"), "bounds error must be readable")

	var in_wall := {"id": "wall_room", "enemies": [{"id": "brick", "spawn": [0, 2], "hp": 5}]}
	var wall_result: Dictionary = CombatEnemyRoster.normalize(in_wall, _arena())
	_check(not bool(wall_result["ok"]), "spawn inside wall must fail")
	_check(_has_error(wall_result, "inside a wall cell"), "wall error must be readable")

	var overlap := {"id": "stack", "enemies": [
		{"id": "a", "spawn": [1, 0], "hp": 5},
		{"id": "b", "spawn": [1, 0], "hp": 5},
	]}
	var overlap_result: Dictionary = CombatEnemyRoster.normalize(overlap, _arena())
	_check(not bool(overlap_result["ok"]), "overlapping spawns must fail")
	_check(_has_error(overlap_result, "overlaps enemy"), "overlap error must be readable")

	var no_spawn := {"id": "drift", "enemies": [{"id": "lost", "hp": 5}]}
	var no_spawn_result: Dictionary = CombatEnemyRoster.normalize(no_spawn, _arena())
	_check(not bool(no_spawn_result["ok"]), "missing spawn must fail")
	_check(_has_error(no_spawn_result, "missing required spawn"), "missing spawn error must be readable")


func _test_state_factory() -> void:
	var room := {"id": "factory", "enemies": [
		{"id": "alpha", "spawn": [1, 0], "hp": 3, "toughness": 1, "traits": ["quick"], "archetype": "armor", "archetype_label": "铁壳"},
		{"id": "beta", "spawn": [2, 0], "hp": 6, "damage": 2},
	]}
	var result: Dictionary = CombatEnemyRoster.normalize(room, _arena())
	var states: Array = CombatEnemyRoster.build_states(result["enemies"])
	_check(states.size() == 2, "factory must build 2 states")
	var alpha: RefCounted = states[0]
	var beta: RefCounted = states[1]
	_check(alpha.get("id") == "alpha" and alpha.get("pos") == Vector2i(1, 0), "alpha mapping id/pos")
	_check(int(alpha.get("max_hp")) == 3 and int(alpha.get("hp")) == 3, "alpha hp mapping")
	_check(str((alpha.get("traits") as Array)[0]) == "quick", "alpha traits mapping")
	_check(str(alpha.get("archetype")) == "armor" and str(alpha.get("archetype_label")) == "铁壳", "alpha archetype mapping")
	_check(int(alpha.get("spawn_order")) == 0 and int(beta.get("spawn_order")) == 1, "spawn_order must follow list order")
	_check(bool(alpha.call("alive")) and bool(beta.call("alive")), "fresh states must be alive")
	alpha.set("hp", 0)
	_check(not bool(alpha.call("alive")), "hp=0 state must not be alive")
	_check(int(beta.get("hp")) == 6, "state objects must be independent")
	var snapshot: Dictionary = alpha.call("debug_snapshot")
	_check(str(snapshot["id"]) == "alpha" and bool(snapshot["alive"]) == false, "debug snapshot must be read-only export")


func _has_error(result: Dictionary, fragment: String) -> bool:
	for line in result.get("errors", []):
		if str(line).find(fragment) >= 0:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
