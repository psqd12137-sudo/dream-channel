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
	var house_presenter = game.house_root.get_node_or_null("LiliToken/Presenter")
	_check(house_presenter != null and house_presenter.has_3d_model(), "the house-map Lili token must reuse the replaceable 3D player presenter")
	_check(_count_type(game.house_root.get_node_or_null("LiliToken"), "Label3D") == 0, "house player hierarchy must not contain overhead UI")
	game.start_combat_lab("hall")
	var player_presenter = game.battle_actor_root.get_node_or_null("Player/Presenter")
	var enemy_presenter = game.battle_actor_root.get_node_or_null("Enemy/Presenter")
	_check(player_presenter != null and player_presenter.sprite is AnimatedSprite3D, "player pawn must use the replaceable character presenter")
	_check(enemy_presenter != null and enemy_presenter.sprite is AnimatedSprite3D, "enemy pawn must use the replaceable character presenter")
	if player_presenter != null:
		_check(_count_type(player_presenter, "Label3D") == 0, "player presenter hierarchy must not contain overhead UI")
		_check(player_presenter.sprite.sprite_frames.get_frame_count("idle") == 12, "Lili idle must use all twelve Web frames")
		_check(is_equal_approx(player_presenter.sprite.sprite_frames.get_animation_speed("idle"), 8.0), "Lili idle must preserve the Web 8 FPS timing")
		_check(player_presenter.has_3d_model(), "player presenter must instantiate the configured Lili model and animation player")
		_check(player_presenter.current_model_animation().ends_with("Lili_Idle"), "player model must begin in its repaired Idle loop")
	if enemy_presenter != null:
		_check(enemy_presenter.has_3d_model(), "enemy presenter must instantiate the temporary Quaternius model and animation player")
		_check(enemy_presenter.current_model_animation().to_lower().contains("idle"), "enemy model must begin in its skeletal Idle loop")
	var ranged_target := Vector2i(2, 1)
	var expected_ranged_yaw := game._battle_move_facing_yaw(game.combat.enemy_pos, ranged_target)
	_check(
		is_equal_approx(game._battle_enemy_attack_facing_yaw(game.battle_actor_root.get_node_or_null("Enemy"), {"target": ranged_target}), expected_ranged_yaw),
		"remote attack facing must turn toward the player target before the attack pose"
	)
	var projectile_start := Vector3(-2.0, 0.84, 0.0)
	var projectile_target := Vector3(2.0, 0.36, 0.0)
	var projectile_middle := game._battle_enemy_projectile_position(0.5, projectile_start, projectile_target)
	_check(projectile_middle.y > maxf(projectile_start.y, projectile_target.y), "remote projectile must rise above both endpoints on its parabolic flight")
	_check(game._battle_enemy_projectile_position(0.0, projectile_start, projectile_target).distance_to(projectile_start) < 0.001, "remote projectile arc must begin at the enemy hand position")
	_check(game._battle_enemy_projectile_position(1.0, projectile_start, projectile_target).distance_to(projectile_target) < 0.001, "remote projectile arc must land at the target position")

	game.combat.player_pos = Vector2i(2, 1)
	game.combat.enemy_pos = Vector2i(7, 1)
	game.combat.walls.clear()
	game.combat.heights.clear()
	game.combat.energy = 5
	game.build_battle_world()
	var board_before_move: Node3D = game.battle_board_root
	var player_before_move: Node3D = game.battle_actor_root.get_node_or_null("Player")
	var full_builds_before_move: int = game.battle_world_renderer.full_board_build_count
	var incremental_refreshes_before_move: int = game.battle_world_renderer.incremental_refresh_count
	game.animation_duration_scale = 0.35
	game.handle_battle_cell(Vector2i(3, 1))
	player_presenter = game.battle_actor_root.get_node_or_null("Player/Presenter")
	_check(game.animation_busy, "a real player grid step must lock input while the pawn moves")
	_check(player_presenter != null and player_presenter.current_model_animation().ends_with("Lili_Walk_InPlace"), "player grid movement must play the repaired in-place Walk loop")
	while game.animation_busy:
		await process_frame
	var moved_player := game.battle_actor_root.get_node_or_null("Player") as Node3D
	_check(moved_player != null and moved_player.position.distance_to(game._battle_world(Vector2i(3, 1))) < 0.01, "player model must settle on the authoritative destination cell")
	_check(game.battle_world_renderer.full_board_build_count == full_builds_before_move, "player arrival must not rebuild the static battle board")
	_check(game.battle_world_renderer.incremental_refresh_count > incremental_refreshes_before_move, "player arrival must refresh dynamic battle state")
	_check(game.battle_board_root == board_before_move, "player arrival must preserve the battle board node")
	_check(moved_player == player_before_move, "player arrival must preserve the animated player node")
	_check(moved_player != null and moved_player.get_node_or_null("PawnLabel") == null, "player hierarchy must not contain overhead UI")
	var last_player_yaw: float = game.battle_player_facing_yaw
	_check(is_equal_approx(last_player_yaw, PI * 0.5), "moving right must record the player's final facing direction")
	game.build_battle_world()
	moved_player = game.battle_actor_root.get_node_or_null("Player") as Node3D
	_check(moved_player != null and is_equal_approx(moved_player.rotation.y, last_player_yaw), "rebuilding the battle board must preserve the player's last facing direction")
	game.animation_duration_scale = 0.0

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
	var full_builds_before_card: int = game.battle_world_renderer.full_board_build_count
	var board_before_card: Node3D = game.battle_board_root
	game.select_or_play_card(0)
	player_presenter = game.battle_actor_root.get_node_or_null("Player/Presenter")
	_check(player_presenter != null and player_presenter.current_state == "ready", "selecting a placement card must trigger a visible ready pose")
	_check(player_presenter != null and player_presenter.action_count == 1, "ready pose must be emitted exactly once for the selection")
	var hp_before: int = game.combat.enemy_hp
	game.handle_battle_cell(game.combat.enemy_pos)
	player_presenter = game.battle_actor_root.get_node_or_null("Player/Presenter")
	enemy_presenter = game.battle_actor_root.get_node_or_null("Enemy/Presenter")
	_check(game.combat.enemy_hp < hp_before, "the presentation test attack must use a real combat hit")
	_check(player_presenter != null and player_presenter.current_state == "attack", "a real player hit must trigger the attack pose")
	_check(enemy_presenter != null and enemy_presenter.current_state == "hurt", "enemy HP loss must trigger the hurt reaction")
	var player_attack_animation := str(game.presentation.get("actors", {}).get("player", {}).get("animation_map", {}).get("attack", ""))
	_check(player_presenter != null and player_presenter.current_model_animation().ends_with(player_attack_animation), "player attack must play the animation declared by the presentation manifest")
	_check(enemy_presenter != null and enemy_presenter.current_model_animation().to_lower().contains("hitreact"), "enemy damage must play the archetype model hit reaction")
	_check(game.battle_world_renderer.full_board_build_count == full_builds_before_card, "card resolution must not rebuild the static battle board")
	_check(game.battle_board_root == board_before_card, "card resolution must preserve the battle board node")

	_check(_count_named_prefix(game.battle_root, "StageDoor") == 1, "battle stage must include the imported Web door decoration")
	_check(_count_named_prefix(game.battle_root, "StageLamp") == 1, "battle stage must include the imported Web lamp decoration")
	_check(_count_named_prefix(game.battle_root, "StageAnchor") == 1, "battle stage must include the imported Web signal anchor")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_PRESENTATION_ANIMATION: PASS 3d-model idle walk attack hurt fallback")
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


func _count_type(node: Node, type_name: String) -> int:
	var count := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		count += _count_type(child, type_name)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
