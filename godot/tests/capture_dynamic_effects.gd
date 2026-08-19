extends SceneTree

const OUTPUT_ROOT := "res://artifacts/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	if packed == null:
		push_error("CAPTURE_DYNAMIC_EFFECTS: main scene did not load")
		quit(1)
		return
	var game: Node3D = packed.instantiate()
	game.animation_duration_scale = 4.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var target: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(target)
	game.place_selected_offer()
	await _capture("room_drop_01_flip.png")
	await create_timer(0.48).timeout
	await _capture("room_drop_02_falling.png")
	while game.animation_busy:
		await process_frame
	await _capture("room_drop_03_settled.png")
	game.enter_room(target)
	await create_timer(1.82).timeout
	await _capture("room_reveal_01_midflip.png")
	while game.animation_busy:
		await process_frame
	await _capture("room_reveal_02_open.png")
	print("CAPTURE_DYNAMIC_EFFECTS: PASS target=%s" % target)
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_ROOT + file_name)
	if error != OK:
		push_error("CAPTURE_DYNAMIC_EFFECTS: failed to save %s (%s)" % [file_name, error_string(error)])
