extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.go_home()
	game.start_kenney_build_lab()
	var room: Dictionary = game._find_catalog_room("hall")
	var target := Vector2i.ZERO
	var rotation := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var valid: Array[int] = game.room_rules.valid_rotations(frontier, room)
		if not valid.is_empty():
			target = frontier
			rotation = valid[0]
			break
	if rotation < 0:
		push_error("CAPTURE_KENNEY_FORMAL_BUILD: no valid five-cell placement")
		quit(1)
		return
	game.selected_frontier = target
	game.build_offers.assign([room])
	game.selected_offer = 0
	game.offer_rotation = rotation
	game.phase = "build"
	game.build_house_world()
	await create_timer(0.8).timeout
	await _capture("res://artifacts/kenney_formal_build_preview.png")
	game.place_selected_offer()
	while game.animation_busy:
		await process_frame
	await create_timer(0.25).timeout
	await _capture("res://artifacts/kenney_formal_build_placed.png")
	print("CAPTURE_KENNEY_FORMAL_BUILD: PASS")
	quit(0)


func _capture(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("CAPTURE_KENNEY_FORMAL_BUILD: failed %s" % path)
