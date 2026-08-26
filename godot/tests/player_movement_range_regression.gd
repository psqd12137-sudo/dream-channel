extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	var combat := CombatRules.new()
	combat.setup(
		{
			"cols": 5,
			"rows": 1,
			"player": [0, 0],
			"walls": [],
			"heights": {},
		},
		{"id": "guard", "name": "守卫", "spawn": [4, 0], "traits": []},
		{},
		[],
		20260825,
		{"player_hp": 20, "base_speed": 3, "base_energy": 2, "hand_size": 4},
		[]
	)
	var reachable := combat.player_reachable_cells()
	_check(Vector2i(1, 0) in reachable, "player movement range must include the first reachable cell")
	_check(Vector2i(2, 0) in reachable, "player movement range must include cells within remaining AP")
	_check(Vector2i(3, 0) not in reachable, "player movement range must exclude cells outside remaining AP")
	combat.energy = 0
	_check(combat.player_reachable_cells().is_empty(), "zero AP must publish no reachable movement cells")
	if failures.is_empty():
		print("CHANNEL_PLAYER_MOVEMENT_RANGE: PASS reachable-cells-ap-boundary")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_PLAYER_MOVEMENT_RANGE: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
