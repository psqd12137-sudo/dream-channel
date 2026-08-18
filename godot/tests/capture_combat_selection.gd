extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var living: Dictionary = {}
	for room: Dictionary in game.room_catalog:
		if str(room.get("id", "")) == "living":
			living = room
			break
	game.start_combat(living)
	game.combat.hand.assign(["jab", "guard", "focus", "tonic"])
	game.combat.energy = 4
	game.select_or_play_card(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://artifacts/combat_selection_fixed.png")
	if error != OK:
		push_error("CAPTURE_COMBAT_SELECTION: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_COMBAT_SELECTION: PASS")
		quit(0)
