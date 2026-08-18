extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
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
	game._refresh_hud()
	await _capture("res://artifacts/presentation_01_idle.png")
	game.select_or_play_card(0)
	await create_timer(0.08).timeout
	await _capture("res://artifacts/presentation_02_ready.png")
	game.handle_battle_cell(game.combat.enemy_pos)
	await create_timer(0.10).timeout
	await _capture("res://artifacts/presentation_03_attack_hurt.png")
	print("CAPTURE_PRESENTATION_ACTIONS: PASS")
	quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_PRESENTATION_ACTIONS: %s" % error_string(error))
