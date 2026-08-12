extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	var player_presenter = game.battle_root.get_node_or_null("Player/Presenter")
	var enemy_presenter = game.battle_root.get_node_or_null("Enemy/Presenter")
	_check(player_presenter != null and player_presenter.sprite is AnimatedSprite3D, "player pawn must use the replaceable character presenter")
	_check(enemy_presenter != null and enemy_presenter.sprite is AnimatedSprite3D, "enemy pawn must use the replaceable character presenter")
	if player_presenter != null:
		_check(player_presenter.sprite.sprite_frames.get_frame_count("idle") == 12, "Lili idle must use all twelve Web frames")
		_check(is_equal_approx(player_presenter.sprite.sprite_frames.get_animation_speed("idle"), 8.0), "Lili idle must preserve the Web 8 FPS timing")

	game.combat.player_pos = Vector2i(3, 1)
	game.combat.enemy_pos = Vector2i(4, 1)
	game.combat.walls.clear()
	game.combat.heights.clear()
	game.combat.enemy_revealed = true
	game.combat.enemy_sees_player = true
	game.combat.player_sees_enemy = true
	game.combat.hand.assign(["jab", "guard", "brace", "fling"])
	game.combat.energy = 4
	game.build_battle_world()
	game.select_or_play_card(0)
	player_presenter = game.battle_root.get_node_or_null("Player/Presenter")
	_check(player_presenter != null and player_presenter.current_state == "ready", "selecting a placement card must trigger a visible ready pose")
	_check(player_presenter != null and player_presenter.action_count == 1, "ready pose must be emitted exactly once for the selection")
	var hp_before: int = game.combat.enemy_hp
	game.handle_battle_cell(game.combat.enemy_pos)
	player_presenter = game.battle_root.get_node_or_null("Player/Presenter")
	enemy_presenter = game.battle_root.get_node_or_null("Enemy/Presenter")
	_check(game.combat.enemy_hp < hp_before, "the presentation test attack must use a real combat hit")
	_check(player_presenter != null and player_presenter.current_state == "attack", "a real player hit must trigger the attack pose")
	_check(enemy_presenter != null and enemy_presenter.current_state == "hurt", "enemy HP loss must trigger the hurt reaction")

	_check(_count_named_prefix(game.battle_root, "StageDoor") == 1, "battle stage must include the imported Web door decoration")
	_check(_count_named_prefix(game.battle_root, "StageLamp") == 1, "battle stage must include the imported Web lamp decoration")
	_check(_count_named_prefix(game.battle_root, "StageAnchor") == 1, "battle stage must include the imported Web signal anchor")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_PRESENTATION_ANIMATION: PASS web-frames ready attack hurt decor")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_PRESENTATION_ANIMATION: %s" % failure)
		quit(1)


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if str(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
