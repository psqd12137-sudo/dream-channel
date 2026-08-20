extends SceneTree

const CombatRules = preload("res://scripts/combat_rules.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var combat = CombatRules.new()
	combat.setup(
		{"cols": 3, "rows": 1, "player": [0, 0], "enemy": [1, 0], "walls": [], "heights": {}},
		{"name": "堵门剪影", "hp": 6, "damage": 1, "action_points": 2, "attack_cost": 2},
		{},
		[],
		20260820,
		{"player_hp": 6, "base_energy": 3, "hand_size": 0, "move_cost": 1, "hostile_pass_cost": 1},
		[],
	)
	_check(combat.player_move_cost(combat.enemy_pos) == 2, "entering an enemy cell must include hostile pass cost")
	combat.energy = 1
	_check(not combat.can_move_player(combat.enemy_pos), "ordinary move AP alone must not pay the hostile pass cost")
	combat.energy = 3
	_check(combat.can_move_player(combat.enemy_pos) and combat.move_player(combat.enemy_pos), "player must be allowed to enter an enemy-occupied doorway")
	_check(combat.player_pos == combat.enemy_pos and combat.energy == 1, "player and enemy must share the logical cell after paying 2 AP")
	_check(combat.can_move_player(Vector2i(2, 0)) and combat.move_player(Vector2i(2, 0)), "player must be able to leave the shared cell through the far side")
	_check(combat.player_pos == Vector2i(2, 0) and combat.energy == 0, "leaving a shared cell must use ordinary move cost")

	combat.player_pos = combat.enemy_pos
	combat.energy = 0
	var shared_intent: Dictionary = combat.preview_intent()
	var hp_before: int = combat.player_hp
	combat.enemy_turn()
	_check(str(shared_intent.get("type", "")) == "attack", "distance-zero co-occupancy must still publish an attack intent")
	_check(combat.player_hp == hp_before - 1, "enemy must treat a co-occupying player as a melee target")

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("living")
	await process_frame
	game.combat.player_pos = game.combat.enemy_pos
	game.build_battle_world()
	var player_node := game.battle_root.get_node_or_null("Player") as Node3D
	var enemy_node := game.battle_root.get_node_or_null("Enemy") as Node3D
	_check(player_node != null and enemy_node != null, "shared cell must keep both rendered pawns")
	if player_node != null and enemy_node != null:
		_check(player_node.position.distance_to(enemy_node.position) >= 0.6, "shared pawns must be visually offset instead of occupying identical pixels")
		var logical_center: Vector3 = game._battle_world(game.combat.player_pos)
		_check(player_node.position.distance_to(logical_center) < 0.5 and enemy_node.position.distance_to(logical_center) < 0.5, "visual offsets must remain inside the shared logical cell")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("CHANNEL_SHARED_CELL: PASS hostile-cost doorway traversal attack visual-offset")
		quit(0)
	else:
		for failure in failures:
			push_error("CHANNEL_SHARED_CELL: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
