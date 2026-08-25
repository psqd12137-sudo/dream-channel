extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	var combat := CombatRules.new()
	combat.setup(
		{
			"cols": 7,
			"rows": 3,
			"player": [0, 1],
			"walls": [],
			"heights": {},
		},
		[
			{"id": "ranged_a", "name": "远射甲", "spawn": [3, 0], "attack_range": 4, "traits": ["ranged"]},
			{"id": "ranged_b", "name": "远射乙", "spawn": [3, 2], "attack_range": 4, "traits": ["ranged"]},
			{"id": "melee", "name": "近战", "spawn": [6, 1], "traits": []},
		],
		{},
		[],
		20260825,
		{"player_hp": 20, "base_speed": 3, "base_energy": 5, "hand_size": 4},
		[]
	)
	var intents: Dictionary = combat.preview_all_intents()
	_check(intents.size() == 3, "bulk intent snapshot must include every living enemy")
	var ranged: Dictionary = intents.get("ranged_a", {})
	_check(str(ranged.get("attack_kind", "")) == "ranged", "snapshot must preserve ranged attack kind")
	_check(Vector2i(0, 1) in ranged.get("impact_cells", []), "snapshot must expose the actual ranged impact cell")
	_check(Vector2i(0, 1) in ranged.get("coverage_cells", []), "snapshot must expose ranged coverage")
	_check(Vector2i(2, 0) in ranged.get("line_cells", []), "snapshot must expose line-of-fire cells")
	var single: Dictionary = combat.preview_intent("ranged_a")
	_check(
		single.get("attack_kind", "") == ranged.get("attack_kind", ""),
		"single intent wrapper must read the bulk snapshot contract"
	)
	var ranged_plan: Dictionary = ranged.get("tactical_plan", {})
	_check(ranged_plan.get("goal", Vector2i(-1, -1)) != Vector2i(-1, -1), "ranged enemy must receive an attack position")
	_check(
		combat.manhattan(ranged_plan.get("goal", Vector2i(-1, -1)), combat.player_pos) > 1,
		"ranged AI attack position must not be forced into melee range"
	)
	if failures.is_empty():
		print("CHANNEL_ENEMY_INTENT_SNAPSHOT: PASS bulk-coverage-impact-line-ranged-position")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_INTENT_SNAPSHOT: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
