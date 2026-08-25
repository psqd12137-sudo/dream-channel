extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []
var cards := {}
var run_rules := {"player_hp": 20, "base_speed": 3, "base_energy": 5, "hand_size": 4, "move_cost": 1}


func _init() -> void:
	_test_ranged_attack()
	_test_ranged_attack_requires_line_of_sight()
	if failures.is_empty():
		print("CHANNEL_RANGED_ENEMY: PASS ranged-intent-line-of-sight-execution")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_RANGED_ENEMY: %s" % failure)
		quit(1)


func _test_ranged_attack() -> void:
	var combat: RefCounted = _build({"cols": 7, "rows": 1, "player": [0, 0], "enemy": [4, 0], "walls": [], "heights": {}, "portals": []})
	var intent: Dictionary = combat.preview_intent()
	var hp_before := int(combat.player_hp)
	var enemy_before: Vector2i = combat.enemy_pos
	var events: Array[Dictionary] = combat.enemy_turn()
	_check(str(intent.get("attack_kind", "")) == "ranged", "ranged enemy must publish a ranged attack intent")
	_check(Vector2i(0, 0) in intent.get("hurt", []), "ranged intent must mark the player cell as dangerous")
	_check(
		Vector2i(0, 0) in intent.get("coverage_cells", []),
		"ranged intent must expose the visible attack range"
	)
	_check(
		Vector2i(3, 0) in intent.get("line_cells", []),
		"ranged intent must expose the line of fire"
	)
	_check(combat.enemy_pos == enemy_before and combat.player_hp == hp_before - 2, "ranged attack must damage from distance without moving")
	_check(events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "attack" and str(event.get("attack_kind", "")) == "ranged"), "ranged turn must emit a ranged attack event")


func _test_ranged_attack_requires_line_of_sight() -> void:
	var combat: RefCounted = _build({"cols": 7, "rows": 1, "player": [0, 0], "enemy": [4, 0], "walls": ["2,0"], "heights": {}, "portals": []})
	var intent: Dictionary = combat.preview_intent()
	var hp_before := int(combat.player_hp)
	var events: Array[Dictionary] = combat.enemy_turn()
	_check(str(intent.get("attack_kind", "")) != "ranged", "a wall must prevent a ranged attack intent")
	_check(combat.player_hp == hp_before, "a wall must prevent ranged damage")
	_check(not events.any(func(event: Dictionary) -> bool: return str(event.get("attack_kind", "")) == "ranged"), "a wall must prevent ranged execution")


func _build(arena: Dictionary) -> RefCounted:
	var combat: RefCounted = CombatRules.new()
	combat.setup(arena, {
		"id": "sentry",
		"name": "远射哨兵",
		"spawn": [4, 0],
		"hp": 10,
		"damage": 2,
		"toughness": 3,
		"action_points": 2,
		"attack_cost": 2,
		"attack_range": 4,
		"traits": ["ranged"],
	}, cards, [], 20260825, run_rules, [])
	return combat


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
