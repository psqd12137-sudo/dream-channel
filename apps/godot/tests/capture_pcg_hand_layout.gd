extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_pcg_hand_layout_lab()
	await create_timer(3.2).timeout
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image := root.get_texture().get_image()
	if image == null:
		push_error("CAPTURE_PCG_HAND_LAYOUT: renderer did not provide an image")
		quit(1)
		return
	var error := image.save_png("res://artifacts/pcg_hand_layout.png")
	if error != OK:
		push_error("CAPTURE_PCG_HAND_LAYOUT: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_PCG_HAND_LAYOUT: PASS")
		quit(0)
