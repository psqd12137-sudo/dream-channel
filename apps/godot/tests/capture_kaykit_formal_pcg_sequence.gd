extends SceneTree

const DESIRED_SIZES := [5, 1, 3, 1, 3, 5, 1]


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
	for desired_size: int in DESIRED_SIZES:
		var placement := _find_placement(game, desired_size)
		if placement.is_empty():
			push_error("CAPTURE_KAYKIT_SEQUENCE: no legal %d-cell placement at step %d" % [desired_size, game.room_rules.instance_count()])
			quit(1)
			return
		game.selected_frontier = placement["frontier"]
		game.build_offers.assign([placement["room"]])
		game.selected_offer = 0
		game.offer_rotation = int(placement["rotation"])
		game.phase = "build"
		game.place_selected_offer()
		await process_frame
	game.reset_house_camera()
	await create_timer(0.6).timeout
	var composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	if composer == null or not composer.visual_geometry_issues.is_empty():
		push_error("CAPTURE_KAYKIT_SEQUENCE: visual edge ledger is invalid")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := root.get_texture().get_image()
	if image == null or image.save_png("res://artifacts/kaykit_formal_pcg_sequence.png") != OK:
		push_error("CAPTURE_KAYKIT_SEQUENCE: screenshot failed")
		quit(1)
		return
	print("CAPTURE_KAYKIT_SEQUENCE: PASS %d rooms %d cells %d visible edges %d junctions" % [composer.rooms.size(), composer.occupancy.size(), composer.visual_edge_records.size(), composer.junction_count])
	quit(0)


func _find_placement(game: Node3D, desired_size: int) -> Dictionary:
	var frontiers: Array[Vector2i] = game.room_rules.frontiers()
	for frontier: Vector2i in frontiers:
		for room: Dictionary in game.remaining_rooms:
			if int(room.get("room_size", 1)) != desired_size:
				continue
			var rotations: Array[int] = game.room_rules.valid_rotations(frontier, room)
			if not rotations.is_empty():
				return {"frontier": frontier, "room": room, "rotation": rotations[0]}
	return {}
