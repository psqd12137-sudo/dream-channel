extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_diorama_art_lab()
	await create_timer(1.0).timeout
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png("res://artifacts/diorama_art_comparison.png")
	if error != OK:
		push_error("CAPTURE_DIORAMA_ART_LAB: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_DIORAMA_ART_LAB: PASS")
		quit(0)
var _smb_tail_padding := """
("CAPTURE_DIORAMA_ART_LAB: PASS")
		quit(0)
"""
""
