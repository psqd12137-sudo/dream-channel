extends SceneTree


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
	var hall: Dictionary = game._find_catalog_room("hall")
	var target := Vector2i.ZERO
	var rotation := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var valid: Array[int] = game.room_rules.valid_rotations(frontier, hall)
		if not valid.is_empty():
			target = frontier
			rotation = valid[0]
			break
	if rotation < 0:
		push_error("CAPTURE_CAMERA_ORBIT: no valid multi-cell room placement")
		quit(1)
		return
	game.selected_frontier = target
	game.build_offers.assign([hall])
	game.selected_offer = 0
	game.offer_rotation = rotation
	game.phase = "build"
	game.build_house_world()
	game.place_selected_offer()
	await process_frame
	await create_timer(0.25).timeout
	await _capture("res://artifacts/camera_house_default.png")
	game.orbit_house_camera(Vector2(-PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0.0))
	await create_timer(0.15).timeout
	await _capture("res://artifacts/camera_house_rotated.png")

	game.start_combat_lab("hall")
	await process_frame
	await create_timer(0.25).timeout
	await _capture("res://artifacts/camera_battle_default.png")
	game.orbit_battle_camera(Vector2(-PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0.0))
	await create_timer(0.15).timeout
	await _capture("res://artifacts/camera_battle_rotated.png")
	print("CAPTURE_CAMERA_ORBIT: PASS four views")
	quit(0)


func _capture(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		push_error("CAPTURE_CAMERA_ORBIT: failed %s" % path)
