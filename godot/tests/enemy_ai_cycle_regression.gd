extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rules := CombatRules.new()
	rules.setup(
		{
			"cols": 8,
			"rows": 6,
			"player": [3, 3],
			"walls": [],
			"heights": {},
		},
		[
			{"id": "hunter", "name": "追猎者", "spawn": [0, 3], "traits": []},
			{"id": "flanker", "name": "侧翼者", "spawn": [7, 3], "traits": ["lunge"]},
			{"id": "controller", "name": "控场者", "spawn": [3, 0], "behavior_role": "controller", "traits": ["beam"]},
		],
		{},
		[],
		20260824,
		{"player_hp": 100, "base_energy": 3},
		[]
	)

	var previous_round := rules.round_number
	for cycle in range(5):
		var plans: Array[Dictionary] = []
		var intents: Array[Dictionary] = []
		for enemy_id in ["hunter", "flanker", "controller"]:
			plans.append(rules.preview_tactical_plan(enemy_id))
			intents.append(rules.preview_intent(enemy_id))
		_check(str(plans[0].get("role", "")) == "hunter", "hunter role must survive cycle %d" % cycle)
		_check(str(plans[1].get("role", "")) == "flanker", "flanker role must survive cycle %d" % cycle)
		_check(str(plans[2].get("role", "")) == "controller", "controller role must survive cycle %d" % cycle)
		_check(str(intents[1].get("ai_role", "")) == "flanker", "intent preview must use the tactical role")
		_check(str(intents[2].get("ai_role", "")) == "controller", "intent preview must use the controller role")
		var goals := [plans[0].get("goal"), plans[1].get("goal"), plans[2].get("goal")]
		_check(goals[0] != goals[1] and goals[1] != goals[2] and goals[0] != goals[2], "cycle %d must reserve independent goals" % cycle)
		var events: Array[Dictionary] = rules.enemy_turn()
		_check(not events.is_empty(), "cycle %d must execute at least one enemy event" % cycle)
		_check(rules.round_number == previous_round + 1, "enemy phase must advance exactly one round")
		previous_round = rules.round_number
		_check(_living_positions_are_unique(rules), "cycle %d must not overlap living enemies" % cycle)
		if rules.outcome != "":
			break
		# 模拟玩家下一拍改变站位，迫使黑板重新感知和选点。
		rules.player_pos = Vector2i(3 + (cycle % 2), 3 + ((cycle + 1) % 2))
		rules.start_player_turn()

	_check(rules.round_number >= 2, "AI must complete more than one full cycle")
	_check(rules.enemy_by_id("hunter").tactical_plan_round < rules.round_number, "completed cycle must expire its tactical snapshot")
	_finish()


func _living_positions_are_unique(rules: CombatRules) -> bool:
	var occupied: Dictionary = {}
	for enemy_id in rules.enemy_order:
		var state = rules.enemy_by_id(enemy_id)
		if state == null or not state.alive():
			continue
		if occupied.has(state.pos):
			return false
		occupied[state.pos] = true
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_ENEMY_AI_CYCLE: PASS preview-plan-execute-replan-5-cycles")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_AI_CYCLE: %s" % failure)
		quit(1)
