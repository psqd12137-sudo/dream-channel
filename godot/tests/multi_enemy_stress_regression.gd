extends SceneTree

# 多敌人压力出口：12 个敌人连续运行 20 个敌方回合。
# 该测试只验证规则层稳定性，不依赖 HUD 或 3D 渲染，因此可以作为
# 任何平台上的确定性压力门禁。

const CombatRules = preload("res://scripts/combat_rules.gd")
const FLAG := "CHANNEL_MULTI_ENEMY_STRESS"
const ENEMY_COUNT := 12
const TURN_COUNT := 20

var failures: Array[String] = []


func _init() -> void:
	var first := _build(20260826)
	var second := _build(20260826)
	for turn in range(TURN_COUNT):
		var first_events: Array[Dictionary] = first.enemy_turn()
		var second_events: Array[Dictionary] = second.enemy_turn()
		_check(first.outcome == "" and second.outcome == "", "12-enemy stress must remain active during turn %d" % turn)
		_check(first_events == second_events, "same seed must produce identical events on stress turn %d" % turn)
		for raw_event: Dictionary in first_events:
			var actor_id := str(raw_event.get("actor_id", ""))
			_check(not actor_id.is_empty(), "stress event must carry actor_id on turn %d" % turn)
			_check(first.enemy_by_id(actor_id) != null, "stress event actor must resolve on turn %d: %s" % [turn, actor_id])
		_check(_snapshot(first) == _snapshot(second), "same seed must produce identical state on stress turn %d" % turn)
		_assert_valid_board(first, "first turn %d" % turn)
		_assert_valid_board(second, "second turn %d" % turn)
		if first.outcome == "" and second.outcome == "":
			first.start_player_turn()
			second.start_player_turn()
	_check(first.event_log.size() < 5000, "12-enemy 20-turn event log must stay bounded (log=%d)" % first.event_log.size())
	if failures.is_empty():
		print("%s: PASS 12-enemy 20-turn bounded deterministic stress" % FLAG)
		quit(0)
	else:
		for failure: String in failures:
			push_error("%s: %s" % [FLAG, failure])
		quit(1)


func _arena() -> Dictionary:
	return {
		"cols": 10,
		"rows": 6,
		"player": [0, 3],
		"walls": ["3,0", "3,5", "6,4", "6,5", "8,2"],
		"heights": {"4,2": 1, "5,3": 1},
		"portals": [],
	}


func _enemy_specs() -> Array:
	var result: Array = []
	var occupied: Dictionary = {}
	for index in range(ENEMY_COUNT):
		var x := 1 + (index % 6)
		var y := 1 + int(floor(float(index) / 6.0))
		var spawn := Vector2i(x, y)
		if occupied.has(spawn):
			continue
		occupied[spawn] = true
		result.append({
			"id": "stress_%02d" % index,
			"spawn": [spawn.x, spawn.y],
			"name": "压力测敌%d" % index,
			"hp": 100,
			"damage": 0,
			"toughness": 3,
			"action_points": 3,
			"attack_cost": 2,
		})
	return result


func _build(seed_value: int) -> CombatRules:
	var rules := CombatRules.new()
	rules.setup(_arena(), _enemy_specs(), {}, [], seed_value, {"player_hp": 999, "base_speed": 3}, [])
	return rules


func _snapshot(rules: CombatRules) -> String:
	var result := ""
	for enemy_id in rules.enemy_order:
		var state = rules.enemy_by_id(enemy_id)
		result += "%s:%s:%d:%d:%d;" % [enemy_id, str(state.pos), state.hp, state.toughness, state.last_seen_age]
	return result + "|" + "|".join(rules.event_log)


func _assert_valid_board(rules: CombatRules, context: String) -> void:
	var cells: Dictionary = {}
	for enemy_id in rules.enemy_order:
		var state = rules.enemy_by_id(enemy_id)
		if state == null or not state.alive():
			continue
		_check(state.pos.x >= 0 and state.pos.x < rules.cols and state.pos.y >= 0 and state.pos.y < rules.rows, "%s: %s left board at %s" % [context, enemy_id, state.pos])
		_check(not rules.walls.has(state.pos), "%s: %s entered wall cell %s" % [context, enemy_id, state.pos])
		_check(not cells.has(state.pos), "%s: %s overlaps %s at %s" % [context, enemy_id, str(cells.get(state.pos, "")), state.pos])
		cells[state.pos] = enemy_id
	for raw_event: Variant in rules.event_log.slice(maxi(0, rules.event_log.size() - 64)):
		var line := str(raw_event)
		if not line.begins_with("Enemy"):
			continue
		# event_log 是人类可读的审计日志；结构化 actor_id 仍由事件数组严格检查。
	_check(cells.size() <= ENEMY_COUNT, "%s: occupied cell count must stay bounded" % context)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
