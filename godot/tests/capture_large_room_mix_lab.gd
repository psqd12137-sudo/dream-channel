extends SceneTree

const OUTPUT_ROOT := "res://artifacts/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.go_home()
	game.start_kenney_build_lab()
	await process_frame

	var chosen_frontier := Vector2i.ZERO
	var chosen_offers: Array[Dictionary] = []
	var best_variety := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var offers: Array[Dictionary] = game._make_build_offers(frontier)
		var sizes: Dictionary = {}
		for room: Dictionary in offers:
			sizes[int(room.get("room_size", 1))] = true
		if sizes.size() > best_variety:
			best_variety = sizes.size()
			chosen_frontier = frontier
			chosen_offers = offers
	game.selected_frontier = chosen_frontier
	game.build_offers = chosen_offers
	game.selected_offer = 0
	game._select_first_valid_rotation()
	game.phase = "build"
	game.build_house_world()
	game._refresh_hud()
	await _capture("large_room_mix_01_offers.png")

	if game.can_place_selected_offer():
		game.place_selected_offer()
		while game.animation_busy:
			await process_frame
		await _capture("large_room_mix_02_placed.png")
		game._finish_enter_room(game.pending_room_pos)
		await process_frame
		await _capture("large_room_mix_03_entered.png")
	print("CAPTURE_LARGE_ROOM_MIX_LAB: PASS")
	quit(0)


func _capture(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.save_png(OUTPUT_ROOT + file_name) != OK:
		push_error("CAPTURE_LARGE_ROOM_MIX_LAB: failed %s" % file_name)
