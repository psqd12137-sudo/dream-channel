extends SceneTree

# 阶段 A 失败测试骨架（multi-enemy refactor plan stage A）。
# 目标契约：
#   - CombatRules 暴露 enemies: Dictionary / enemy_order: Array[String]
#   - 集中查询 living_enemy_ids / enemy_by_id / enemy_at / occupied_enemy_cells / all_enemies_defeated
#   - setup() 第二参数接受标准敌人数组（旧单敌人字典在加载边界转换）
# 在生产代码实现前，本脚本必须以 missing-contract 失败；失败原因必须是
# 功能缺失，而不是脚本编译或语法错误，因此所有未来契约访问都走动态分派。

const CombatRules = preload("res://scripts/combat_rules.gd")

const FLAG := "CHANNEL_MULTI_ENEMY_STATE"
const COUNTS := [1, 2, 4, 8, 12]

var failures: Array[String] = []


func _init() -> void:
	var probe: Variant = CombatRules.new()
	if not _has_multi_enemy_contract(probe):
		failures.append("missing-contract: CombatRules must expose enemies/enemy_order plus living_enemy_ids/enemy_by_id/enemy_at/occupied_enemy_cells/all_enemies_defeated")
	else:
		_test_count_matrix()
		_test_id_uniqueness()
		_test_state_isolation()
		_test_defeat_semantics()
	if failures.is_empty():
		print("%s: PASS ids-isolated 1-2-4-8-12" % FLAG)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [FLAG, failure])
		print("%s: FAIL count=%d" % [FLAG, failures.size()])
		quit(1)


func _has_multi_enemy_contract(rules: Variant) -> bool:
	if rules.get("enemies") == null or rules.get("enemy_order") == null:
		return false
	var required := [
		"living_enemy_ids",
		"enemy_by_id",
		"enemy_at",
		"occupied_enemy_cells",
		"all_enemies_defeated",
	]
	for method in required:
		if not rules.call("has_method", method):
			return false
	return true


func _build_combat(count: int) -> Variant:
	var arena := {
		"cols": 6,
		"rows": 3,
		"player": [0, 1],
		"walls": [],
		"heights": {},
		"portals": [],
		"ambush": false,
	}
	var enemies: Array = []
	for i in range(count):
		enemies.append({
			"id": "unit_%02d" % i,
			"spawn": [1 + (i % 5), int(floor(i / 5.0))],
			"name": "测试单位%d" % i,
			"hp": 3 + (i % 3),
			"damage": 1,
			"toughness": 2,
			"action_points": 2,
			"attack_cost": 2,
		})
	var rules: Variant = CombatRules.new()
	rules.call("setup", arena, enemies, {}, [], 7, {"player_hp": 6, "base_speed": 3}, [])
	return rules


func _test_count_matrix() -> void:
	for n in COUNTS:
		var rules: Variant = _build_combat(n)
		var living: Array = rules.call("living_enemy_ids")
		_check(living.size() == n, "N=%d must expose %d living ids, got %d" % [n, n, living.size()])
		var order: Array = rules.call("get", "enemy_order")
		_check(order.size() == n, "N=%d enemy_order must hold %d ids, got %d" % [n, n, order.size()])
		_check(not rules.call("all_enemies_defeated"), "N=%d fresh combat must not be defeated" % n)
		for i in range(n):
			var enemy: Variant = rules.call("enemy_by_id", "unit_%02d" % i)
			_check(enemy != null, "N=%d enemy_by_id(unit_%02d) must resolve" % [n, i])
			if enemy != null:
				_check(int(enemy.get("hp")) == 3 + (i % 3), "N=%d unit_%02d hp mismatch" % [n, i])


func _test_id_uniqueness() -> void:
	var rules: Variant = _build_combat(8)
	var seen := {}
	for id in rules.call("living_enemy_ids"):
		var key := str(id)
		_check(key != "", "enemy_id must be non-empty")
		_check(not seen.has(key), "enemy_id must be unique in combat, dup=%s" % key)
		seen[key] = true
	var cells := rules.call("occupied_enemy_cells") as Dictionary
	_check(cells.size() == 8, "fresh 8-enemy combat must occupy 8 cells, got %d" % cells.size())
	for cell in cells.keys():
		var at_cell: Variant = rules.call("enemy_at", cell)
		_check(at_cell != null, "enemy_at(%s) must resolve an occupant" % str(cell))


func _test_state_isolation() -> void:
	var rules: Variant = _build_combat(2)
	var a: Variant = rules.call("enemy_by_id", "unit_00")
	var b: Variant = rules.call("enemy_by_id", "unit_01")
	var a_spawn: Vector2i = a.get("pos")
	var b_spawn: Vector2i = b.get("pos")
	a.set("hp", 1)
	a.set("pos", Vector2i(5, 2))
	_check(int(b.get("hp")) == 4, "writing unit_00 hp must not change unit_01 hp")
	_check(b.get("pos") == b_spawn, "moving unit_00 must not move unit_01")
	_check(a.get("pos") == Vector2i(5, 2), "state write via enemy object must stick")
	_check(int(rules.call("enemy_by_id", "unit_00").get("hp")) == 1, "enemy_by_id must return the authoritative object, not a copy")
	var at_moved: Variant = rules.call("enemy_at", Vector2i(5, 2))
	_check(at_moved != null and str(at_moved.get("id")) == "unit_00", "enemy_at must track unit_00 after move")


func _test_defeat_semantics() -> void:
	var rules: Variant = _build_combat(2)
	rules.call("enemy_by_id", "unit_00").set("hp", 0)
	var living: Array = rules.call("living_enemy_ids")
	_check(living.size() == 1 and str(living[0]) == "unit_01", "dead enemy must leave living list, got %s" % str(living))
	_check(not rules.call("all_enemies_defeated"), "one of two dead must not count as all defeated")
	_check(str(rules.call("get", "outcome")) == "", "partial kill must not set outcome")
	rules.call("enemy_by_id", "unit_01").set("hp", 0)
	_check(rules.call("all_enemies_defeated"), "all dead must be detected as defeated")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
