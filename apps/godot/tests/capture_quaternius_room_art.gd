extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false)
	game.choose_omen(0)
	game.room_rules.placed.clear()
	var showcase := {
		Vector2i(-1, -1): "hall",
		Vector2i(0, -1): "parlor",
		Vector2i(-1, 0): "west_wing",
		Vector2i(0, 0): "cellar",
	}
	for raw_pos: Vector2i in showcase:
		var room: Dictionary = game._find_catalog_room(showcase[raw_pos]).duplicate(true)
		room["revealed"] = true
		room["completed"] = true
		game.room_rules.placed[raw_pos] = room
	game.current_room_pos = Vector2i(-1, -1)
	game.phase = "explore"
	game.status_message = "CC0 微缩布景校准：长廊 / 会客室 / 西厢 / 地窖。"
	game.build_house_world()
	game._refresh_hud()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png("res://artifacts/quaternius_room_art.png")
	if error != OK:
		push_error("CAPTURE_QUATERNIUS_ROOM_ART: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_QUATERNIUS_ROOM_ART: PASS")
		quit(0)
