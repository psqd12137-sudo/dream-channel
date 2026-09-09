extends SceneTree

var game: Node3D
var output_dir := "res://../output/memphis-toyhouse/before"

func _init() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output_dir = OS.get_cmdline_user_args()[0]
	call_deferred("_run")

func _run() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("Capture timed out"); quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new(output_dir + "/capture-save.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	await process_frame
	root.size = Vector2i(1920, 1080)
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	for size_value: int in [1, 3, 5]:
		_add_room(size_value)
	game.build_house_world()
	game._refresh_hud()
	game.presentation_settings.depth_of_field_enabled = false
	game.presentation_settings._apply_depth_of_field_state()
	await _capture("rooms")
	var frontier: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(frontier)
	await _capture("preview")
	game.cancel_build()
	for index in range(24):
		if game.room_rules.instance_count() >= 12:
			break
		_add_room([1, 3, 5][index % 3])
	game.build_house_world()
	game._refresh_hud()
	await _capture("map12")
	print("CAPTURE_MAP_ROOMS: ", game.room_rules.instance_count())
	var frame_times: Array[float] = []
	for index in range(120):
		var started := Time.get_ticks_usec()
		await process_frame
		frame_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
	frame_times.sort()
	print("CAPTURE_PERFORMANCE: p95_ms=", frame_times[113], " nodes=", get_node_count(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var hall: Dictionary = game._find_catalog_room("hall")
	for cell: Vector2i in game.room_rules.frontiers():
		var rotations: Array = game.room_rules.valid_rotations(cell, hall)
		if rotations.is_empty():
			continue
		game.begin_build(cell)
		game.build_offers.assign([hall])
		game.selected_offer = 0
		game.offer_rotation = rotations[0]
		game.build_house_world()
		await _capture("five_cell_preview")
		game.animation_duration_scale = 4.0
		game.place_selected_offer()
		await _capture("module_landing")
		var deadline := Time.get_ticks_msec() + 15000
		while game.active_animation_kind == "room_drop" and Time.get_ticks_msec() < deadline:
			await process_frame
		await _capture("actor_hop")
		while game.animation_busy and Time.get_ticks_msec() < deadline:
			await process_frame
		await _capture("room_ready")
		break
	game.animation_duration_scale = 0.0
	game.start_combat_lab("hall")
	await _capture("battle")
	print("MEMPHIS_CAPTURE: ", output_dir)
	game.queue_free()
	await process_frame
	quit()

func _add_room(size_value: int) -> void:
	for room: Dictionary in game.room_catalog:
		if int(room.get("room_size", 1)) != size_value or str(room.get("id", "")) in ["foyer", "ritual"]:
			continue
		for cell: Vector2i in game.room_rules.frontiers():
			var rotations: Array = game.room_rules.valid_rotations(cell, room)
			if rotations.is_empty():
				continue
			if game.room_rules.place(cell, room, int(rotations[0])):
				game.room_rules.set_instance_flag(cell, "revealed", true)
				game.room_rules.set_instance_flag(cell, "visited", true)
				return

func _capture(label: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output_dir + "/" + label + ".png")
	if result != OK:
		push_error("Capture failed: " + error_string(result))
		quit(1)
