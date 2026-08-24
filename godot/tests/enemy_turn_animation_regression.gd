extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	game.animation_duration_scale = 0.35
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	game.combat.ambush_active = false
	game.combat.ambush_idle_turns = 1
	game.combat.enemy_revealed = false
	game.combat.player_sees_enemy = false
	game.combat.enemy_sees_player = false
	game.combat.last_seen = game.combat.INVALID_CELL
	game.combat.patrol_goal = game.combat.INVALID_CELL
	game.build_battle_world()
	var start: Vector2i = game.combat.enemy_pos
	var enemy_node_before := game.battle_actor_root.get_node_or_null("Enemy") as Node3D
	game.end_combat_turn()
	_check(game.animation_busy, "enemy patrol must lock player input while its motion tween is running")
	var enemy_node := game.battle_actor_root.get_node_or_null("Enemy") as Node3D
	_check(enemy_node != null, "enemy pawn must remain available for patrol animation")
	_check(enemy_node == enemy_node_before, "enemy patrol must animate the existing pawn without rebuilding it first")
	if enemy_node != null:
		_check(enemy_node.position.distance_to(game._battle_world(start)) < 0.01, "enemy patrol must render from its event source on the first frame")
	var visibly_departed := false
	var saw_walk_animation := false
	if enemy_node != null:
		var source_world: Vector3 = game._battle_world(start)
		while game.animation_busy:
			await process_frame
			if is_instance_valid(enemy_node) and enemy_node.position.distance_to(source_world) > 0.01:
				visibly_departed = true
			if is_instance_valid(enemy_node):
				var presenter = enemy_node.get_node_or_null("Presenter")
				if presenter != null and presenter.current_model_animation().to_lower().contains("walk"):
					saw_walk_animation = true
	_check(visibly_departed, "enemy pawn must visibly leave its source cell during patrol tween")
	_check(saw_walk_animation, "enemy patrol tween must drive the temporary 3D model Walk loop")
	while game.animation_busy:
		await process_frame
	_check(game.combat.enemy_pos != start, "enemy rules position must finish on a different patrol cell")
	var settled_enemy := game.battle_actor_root.get_node_or_null("Enemy") as Node3D
	_check(settled_enemy != null and settled_enemy.position.distance_to(game._battle_world(game.combat.enemy_pos)) < 0.01, "rendered enemy must settle on the authoritative patrol destination")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_ENEMY_TURN_ANIMATION: PASS lock tween settle")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ENEMY_TURN_ANIMATION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
