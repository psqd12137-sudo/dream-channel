extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rules := CombatRules.new()
	rules.setup(
		{
			"cols": 7,
			"rows": 5,
			"player": [3, 2],
			"enemy": [0, 2],
			"walls": [],
		"heights": {"0,0": 1},
		},
		[
			{"id": "front", "name": "正面猎手", "spawn": [0, 2], "traits": []},
			{"id": "side", "name": "侧翼猎手", "spawn": [6, 2], "traits": ["lunge"]},
			{"id": "control", "name": "控场猎手", "spawn": [3, 0], "behavior_role": "controller", "traits": ["beam"]},
		],
		{},
		[],
		20260824,
		{},
		[]
	)
	var front_plan: Dictionary = rules.preview_tactical_plan("front")
	var side_plan: Dictionary = rules.preview_tactical_plan("side")
	var control_plan: Dictionary = rules.preview_tactical_plan("control")
	_check(str(front_plan.get("role", "")) == "hunter", "default enemy must become hunter")
	_check(str(side_plan.get("role", "")) == "flanker", "lunge enemy must become flanker")
	_check(str(control_plan.get("role", "")) == "controller", "explicit controller role must be preserved")
	_check(str(side_plan.get("state", "")) == "flank", "flanker must receive flank state")
	_check(str(control_plan.get("state", "")) == "control", "controller must receive control state")
	var goals := [front_plan.get("goal", Vector2i(-1, -1)), side_plan.get("goal", Vector2i(-1, -1)), control_plan.get("goal", Vector2i(-1, -1))]
	_check(goals[0] != goals[1] and goals[1] != goals[2] and goals[0] != goals[2], "living enemies must reserve different tactical goals")
	var reservations := [front_plan.get("reserved_cell", Vector2i(-1, -1)), side_plan.get("reserved_cell", Vector2i(-1, -1)), control_plan.get("reserved_cell", Vector2i(-1, -1))]
	_check(reservations[0] != reservations[1] and reservations[1] != reservations[2], "attack slots must not overlap")
	var events: Array[Dictionary] = rules.enemy_turn()
	_check(not events.is_empty(), "planned enemies must still execute through the existing action layer")
	_check(rules.enemy_by_id("front").ai_state != "", "executed enemy must retain a tactical state for inspection")
	_check(rules.enemy_by_id("side").ai_role == "flanker", "execution must preserve the side enemy role")
	_check(rules.enemy_by_id("control").ai_role == "controller", "execution must preserve the controller role")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_ENEMY_AI_TACTICAL: PASS roles states reservations execution")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_AI_TACTICAL: %s" % failure)
		quit(1)
