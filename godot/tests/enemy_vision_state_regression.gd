extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy := {"name": "Watcher", "hp": 6, "damage": 2, "action_points": 3, "attack_cost": 2}
	var open_arena := {"cols": 5, "rows": 5, "player": [0, 0], "enemy": [4, 4], "walls": [], "heights": {}}
	var combat = CombatRules.new()
	combat.setup(open_arena, enemy, {}, [], 88, {"player_hp": 6, "base_speed": 3, "hand_size": 0, "dice_faces": [0]}, [])
	_check(combat.enemy_sees_player, "diagonal raster sight must acquire the player on an open board")
	_check(str(combat.preview_intent().get("type", "")) == "chase", "open diagonal sight must publish chase intent")

	combat.walls[Vector2i(2, 2)] = true
	combat._refresh_vision(false)
	_check(not combat.enemy_sees_player, "a wall crossed by the raster sight line must block enemy vision")
	_check(combat.last_seen == combat.player_pos, "losing sight must retain the last seen player cell")
	_check(str(combat.preview_intent().get("type", "")) == "search", "lost sight with memory must publish search intent")
	for i in range(combat.LAST_SEEN_MEMORY_TURNS):
		combat._finish_enemy_turn()
	_check(combat.last_seen == combat.INVALID_CELL, "last-seen memory must expire after the Web-equivalent five turns")
	_check(str(combat.preview_intent().get("type", "")) == "patrol", "expired memory must fall back to patrol instead of freezing")

	var adjacent_arena := {"cols": 3, "rows": 2, "player": [0, 0], "enemy": [1, 0], "walls": [], "heights": {}}
	var adjacent = CombatRules.new()
	adjacent.setup(adjacent_arena, enemy, {}, [], 91, {"player_hp": 6, "base_speed": 3, "hand_size": 0, "dice_faces": [0]}, [])
	var attack_intent: Dictionary = adjacent.preview_intent()
	_check(str(attack_intent.get("type", "")) == "attack", "adjacent sight must publish attack intent")
	_check((attack_intent.get("hurt", []) as Array).has(adjacent.player_pos), "attack intent must visibly mark the hurt cell")
	adjacent.enemy_action_points = 1
	var occupied_before: Vector2i = adjacent.enemy_pos
	var low_ap_events: Array[Dictionary] = adjacent.enemy_turn()
	_check(adjacent.enemy_pos == occupied_before, "enemy without attack AP must wait rather than overlap the player cell")
	_check(low_ap_events.any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "wait"), "insufficient attack AP must emit an explicit wait event")

	if failures.is_empty():
		print("CHANNEL_ENEMY_VISION_STATE: PASS diagonal wall memory patrol attack-wait")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_VISION_STATE: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
