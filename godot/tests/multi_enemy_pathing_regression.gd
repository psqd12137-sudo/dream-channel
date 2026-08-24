extends SceneTree

# 阶段 D：多敌人占格、寻路与传送门回归。
# 覆盖：动态阻挡、窄通道、无路等待、传送门出口占用、
# 4 敌 20 回合无重叠/越界/死循环。

const CombatRules = preload("res://scripts/combat_rules.gd")

const FLAG := "CHANNEL_MULTI_ENEMY_PATHING"

var failures: Array[String] = []


func _init() -> void:
	_test_dynamic_blocking()
	_test_narrow_corridor_no_overlap()
	_test_no_path_wait_event()
	_test_portal_exit_occupied()
	_test_four_enemies_20_turns()
	if failures.is_empty():
		print("%s: PASS dynamic-block corridor no-path-wait portal-occupied 20-turn-stress" % FLAG)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [FLAG, failure])
		print("%s: FAIL count=%d" % [FLAG, failures.size()])
		quit(1)


func _build(arena: Dictionary, enemy_specs: Array, seed_value: int, player_hp := 60) -> CombatRules:
	var rules := CombatRules.new()
	rules.setup(arena, enemy_specs, {}, [], seed_value, {"player_hp": player_hp, "base_speed": 3}, [])
	return rules


func _standard_specs(count: int, cols: int) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({
			"id": "walker_%02d" % i,
			"spawn": [1 + (i % (cols - 1)), 1 + int(floor(float(i) / float(cols - 1)))],
			"name": "占格测敌%d" % i,
			"hp": 30,
			"damage": 1,
			"toughness": 3,
			"action_points": 3,
			"attack_cost": 2,
		})
	return result


func _assert_no_overlap(rules: CombatRules, context: String) -> void:
	var cells: Dictionary = {}
	for enemy_id in rules.enemy_order:
		var state: RefCounted = rules.enemies[enemy_id]
		if not state.alive():
			continue
		_check(state.pos.x >= 0 and state.pos.y >= 0 and state.pos.x < rules.cols and state.pos.y < rules.rows, "%s: enemy %s out of bounds at %s" % [context, enemy_id, state.pos])
		_check(not cells.has(state.pos), "%s: enemies %s and %s overlap at %s" % [context, str(cells.get(state.pos, "")), enemy_id, state.pos])
		cells[state.pos] = enemy_id


func _test_dynamic_blocking() -> void:
	# 单格宽走廊：敌 A 在 (2,1)，敌 B 在 (3,1)。B 想去 A 身后必须绕行或等待，
	# 不允许穿过 A 或与 A 同格。
	var arena := {
		"cols": 6,
		"rows": 3,
		"player": [5, 1],
		"walls": ["0,0", "1,0", "2,0", "3,0", "4,0", "0,2", "1,2", "2,2", "3,2", "4,2"],
		"heights": {},
		"portals": [],
	}
	var rules := _build(arena, [
		{"id": "blocker", "spawn": [2, 1], "name": "阻挡者", "hp": 30, "damage": 1, "toughness": 3, "action_points": 3, "attack_cost": 2},
		{"id": "pusher", "spawn": [3, 1], "name": "跟随者", "hp": 30, "damage": 1, "toughness": 3, "action_points": 3, "attack_cost": 2},
	], 31)
	for turn in range(10):
		rules.enemy_turn()
		if rules.outcome != "":
			break
		rules.start_player_turn()
		_assert_no_overlap(rules, "corridor turn %d" % turn)


func _test_narrow_corridor_no_overlap() -> void:
	# 四敌挤在 1×4 的竖井里也不允许重叠。
	var arena := {
		"cols": 3,
		"rows": 6,
		"player": [2, 5],
		"walls": ["0,0", "1,0", "0,1", "1,2", "0,3", "1,3", "0,4", "1,4"],
		"heights": {},
		"portals": [],
	}
	var rules := _build(arena, [
		{"id": "well_a", "spawn": [2, 1], "name": "井甲", "hp": 30, "damage": 1, "toughness": 3, "action_points": 2, "attack_cost": 2},
		{"id": "well_b", "spawn": [2, 2], "name": "井乙", "hp": 30, "damage": 1, "toughness": 3, "action_points": 2, "attack_cost": 2},
		{"id": "well_c", "spawn": [2, 3], "name": "井丙", "hp": 30, "damage": 1, "toughness": 3, "action_points": 2, "attack_cost": 2},
		{"id": "well_d", "spawn": [2, 4], "name": "井丁", "hp": 30, "damage": 1, "toughness": 3, "action_points": 2, "attack_cost": 2},
	], 41, 80)
	for turn in range(12):
		rules.enemy_turn()
		if rules.outcome != "":
			break
		rules.start_player_turn()
		_assert_no_overlap(rules, "well turn %d" % turn)


func _test_no_path_wait_event() -> void:
	# 敌人被墙完全围死：没有任何可达巡逻点，必须产生带 actor_id 的 wait 而非死循环。
	var arena := {
		"cols": 5,
		"rows": 3,
		"player": [0, 0],
		"walls": ["1,0", "3,0", "1,1", "2,1", "3,1", "1,2", "2,2", "3,2"],
		"heights": {},
		"portals": [],
	}
	var rules := _build(arena, [
		{"id": "walled", "spawn": [2, 0], "name": "困兽", "hp": 9, "damage": 1, "toughness": 2, "action_points": 3, "attack_cost": 2},
	], 51, 60)
	var events: Array = rules.enemy_turn()
	var waited := false
	for raw_event in events:
		var event: Dictionary = raw_event
		if str(event.get("kind", "")) == "wait":
			waited = true
			_check(str(event.get("actor_id", "")) == "walled", "wait event must carry the walled enemy's actor_id")
	_check(waited, "enemy with no reachable goal must emit a wait event")
	_check(rules.event_log.size() < 400, "walled enemy must not loop forever (log=%d lines)" % rules.event_log.size())


func _test_portal_exit_occupied() -> void:
	# 传送门 (0,0)<->(4,2)。出口 (4,2) 被敌 B 占据：敌 A 不得传送到 B 头上。
	var arena := {
		"cols": 5,
		"rows": 3,
		"player": [4, 1],
		"walls": ["1,0", "1,1", "1,2", "3,0", "3,1", "3,2"],
		"heights": {},
		"portals": [["0,0", "4,2"]],
	}
	var rules := _build(arena, [
		{"id": "jumper", "spawn": [0, 0], "name": "跳跃者", "hp": 30, "damage": 1, "toughness": 3, "action_points": 3, "attack_cost": 2},
		{"id": "plug", "spawn": [4, 2], "name": "堵门者", "hp": 30, "damage": 1, "toughness": 3, "action_points": 1, "attack_cost": 2},
	], 61, 60)
	for turn in range(8):
		rules.enemy_turn()
		if rules.outcome != "":
			break
		rules.start_player_turn()
		_assert_no_overlap(rules, "portal turn %d" % turn)
	# jumper 任何时候都不能出现在 plug 的当前格。
	_check(rules.enemies["jumper"].pos != rules.enemies["plug"].pos, "jumper must never land on plug's cell")


func _test_four_enemies_20_turns() -> void:
	var arena := {
		"cols": 8,
		"rows": 5,
		"player": [0, 2],
		"walls": ["3,0", "4,2", "3,4"],
		"heights": {},
		"portals": [],
	}
	var rules := _build(arena, _standard_specs(4, 8), 71, 90)
	for turn in range(20):
		rules.enemy_turn()
		if rules.outcome != "":
			break
		rules.start_player_turn()
		_assert_no_overlap(rules, "stress turn %d" % turn)
	_check(rules.event_log.size() < 3000, "20 turns must not explode the event log (log=%d)" % rules.event_log.size())


func _check(condition: bool, message: String) -> void:
	if not condition:
		if message != "":
			failures.append(message)
