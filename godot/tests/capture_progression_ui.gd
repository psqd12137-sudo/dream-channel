extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game._clear_run_save()
	game.start_new_run(false, 2026081901)
	await _capture("res://artifacts/progression_00_omen.png")
	game.choose_omen(0)
	game._start_card_reward("capture")
	await _capture("res://artifacts/progression_01_reward.png")
	game.start_chase_lab()
	await _capture("res://artifacts/progression_02_chase.png")
	game._clear_run_save()
	print("CAPTURE_PROGRESSION_UI: PASS")
	quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("CAPTURE_PROGRESSION_UI: %s" % error_string(error))
