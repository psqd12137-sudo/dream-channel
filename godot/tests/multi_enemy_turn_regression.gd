extends SceneTree

# 阶段 D：多敌人敌方回合调度回归。
# 覆盖：稳定顺序、死亡跳过、玩家死亡中止、阶段中新增敌人延后行动、
# 全部敌人事件携带有效 actor_id、固定种子确定性。

const CombatRules = preload("res://scripts/combat_rules.gd")
const EnemyTurnScheduler = preload("res://scripts/enemy_turn_scheduler.gd")

const FLAG := "CHANNEL_MULTI_ENEMY_TURN"

var failures: Array[String] = []


func _init() -> void:
	_test_stable_order_and_actor_ids()
	_test_dead_enemy_skipped()
	_test_player_death_stops_queue()
	_test_mid_turn_spawn_waits()
	_test_determinism_three_runs()
	if failures.is_empty():
		print("%s: PASS stable-order death-skip player-death-stop spawn-defer determinism" % FLAG)
		quit(0)
	else:
		for failure in failures:
			push_error("%s: %s" % [FLAG, failure])
		print("%s: FAIL count=%d" % [FLAG, failures.size()])
		quit(1)


func _arena(cols := 8, rows := 5) -> Dictionary:
	return {
		"cols": cols,
		"rows": rows,
		"player": [0, 2],
		"walls": [],
		"heights": {},
		"portals": [],
	}


func _enemies(count: int, hp := 20, damage := 1) -> Array:
	var result: Array = []
	for i in range(count):
		result.append({
			"id": "foe_%02d" % i,
			"spawn": [2 + i, 1 + (i % 3)],
			"name": "调度测敌%d" % i,
			"hp": hp,
			"damage": damage,
			"toughness": 2,
			"action_points": 2,
			"attack_cost": 2,
		})
	return result


func _build(count: int, seed_value: int, hp := 20, damage := 1) -> CombatRules:
	var rules := CombatRules.new()
	rules.setup(_arena(), _enemies(count, hp, damage), {}, [], seed_value, {"player_hp": 40, "base_speed": 3}, [])
	return rules


func _test_stable_order_and_actor_ids() -> void:
	var rules := _build(4, 11)
	var events: Array = rules.enemy_turn()
	_check(events.size() > 0, "4 living enemies must produce at least one event")
	var actors: Array = []
	for raw_event in events:
		var event: Dictionary = raw_event
		var actor := str(event.get("actor_id", ""))
		_check(actor != "", "every enemy event must carry actor_id, got %s" % str(event))
		_check(rules.enemy_by_id(actor) != null, "actor_id '%s' must resolve to a known enemy" % actor)
		if not actors.has(actor):
			actors.append(actor)
	# 敌人首次行动的相对顺序必须与 enemy_order 一致。
	var order: Array = rules.enemy_order
	var rank: Array = []
	for actor in actors:
		rank.append(order.find(actor))
	for i in range(rank.size() - 1):
		_check(int(rank[i]) < int(rank[i + 1]), "enemy first actions must follow enemy_order, got %s" % str(actors))


func _test_dead_enemy_skipped() -> void:
	var rules := _build(3, 12)
	rules.enemy_by_id("foe_01").hp = 0
	var events: Array = rules.enemy_turn()
	for raw_event in events:
		_check(str((raw_event as Dictionary).get("actor_id", "")) != "foe_01", "dead foe_01 must not act")


func _test_player_death_stops_queue() -> void:
	# 玩家 HP 2、敌人伤害 3：一旦有敌人贴近即可致死；
	# 致死后队列里任何尚未行动的敌人不得再行动。
	var rules := _build(4, 13, 20, 3)
	rules.player_hp = 2
	var player_died_at := -1
	var later_actors: Array = []
	var seen: Array = []
	var killer := ""
	for cycle in range(4):
		seen.clear()
		later_actors.clear()
		player_died_at = -1
		var events: Array = rules.enemy_turn()
		var order: Array = rules.enemy_order
		for raw_event in events:
			var event: Dictionary = raw_event
			var actor := str(event.get("actor_id", ""))
			if not seen.has(actor):
				seen.append(actor)
			if rules.player_hp <= 0 and player_died_at == -1:
				player_died_at = seen.find(actor)
				killer = actor
			elif player_died_at != -1 and not later_actors.has(actor):
				later_actors.append(actor)
		if rules.outcome == "defeat":
			_check(player_died_at != -1, "player must die during the queue")
			var killer_rank := order.find(killer)
			for actor in later_actors:
				_check(order.find(actor) > killer_rank, "enemy %s acted after player death" % actor)
			for enemy_id in order:
				if order.find(enemy_id) > killer_rank and killer_rank >= 0:
					_check(not seen.has(enemy_id), "enemy %s must not act after the killer" % enemy_id)
			return
		rules.start_player_turn()
	_check(false, "player must eventually be defeated by 4 damage-3 enemies with 2 hp, outcome=%s" % rules.outcome)


func _test_mid_turn_spawn_waits() -> void:
	var rules := _build(2, 14)
	var late := {
		"id": "foe_late",
		"spawn": [6, 3],
		"name": "迟到单位",
		"hp": 9,
		"damage": 1,
		"toughness": 2,
		"action_points": 2,
		"attack_cost": 2,
	}
	# 模拟阶段中生成：直接把新敌人写入集合，但传给调度器一份
	# 不含它的旧队列快照（等价于它在本阶段开始后才出现）。
	var roster_script = load("res://scripts/combat_enemy_roster.gd")
	var normalized: Dictionary = roster_script.normalize({"id": "late_room", "enemies": [late]}, _arena())
	var spawned: RefCounted = roster_script.build_states(normalized["enemies"])[0]
	rules.enemies["foe_late"] = spawned
	rules.enemy_order.append("foe_late")
	var scheduler := EnemyTurnScheduler.new(rules)
	var events: Array = scheduler.run_turn(["foe_00", "foe_01"])
	for raw_event in events:
		_check(str((raw_event as Dictionary).get("actor_id", "")) != "foe_late", "mid-turn spawned enemy must wait for next phase")
	_check(spawned.hp == 9, "waiting enemy must not take trap or combat damage")
	# 下一阶段（正常调用）它必须行动。
	var next_events: Array = rules.enemy_turn()
	var acted := false
	for raw_event in next_events:
		if str((raw_event as Dictionary).get("actor_id", "")) == "foe_late":
			acted = true
	_check(acted or rules.outcome != "", "deferred enemy must act in the next enemy phase")


func _test_determinism_three_runs() -> void:
	var logs: Array = []
	var states: Array = []
	for run in range(3):
		var rules := _build(4, 2026)
		for turn in range(8):
			rules.enemy_turn()
			if rules.outcome != "":
				break
			rules.start_player_turn()
		var dump := ""
		for enemy_id in rules.enemy_order:
			var state: RefCounted = rules.enemies[enemy_id]
			dump += "%s:%d:%s;" % [enemy_id, state.hp, state.pos]
		logs.append(dump + "|" + "|".join(rules.event_log))
		states.append(dump)
	_check(str(logs[0]) == str(logs[1]) and str(logs[1]) == str(logs[2]), "same seed must produce identical event logs and states across 3 runs")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
