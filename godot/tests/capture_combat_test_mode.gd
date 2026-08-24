extends SceneTree

const OUTPUT_ROOT := "res://artifacts/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.open_combat_test_mode()
	await process_frame
	await _capture("combat_test_mode_menu.png")
	game.select_combat_test_scenario("squad_roles")
	game.start_test_combat("manual")
	await process_frame
	await _capture("combat_test_mode_manual_squad.png")
	game.return_to_combat_test_menu()
	game.go_home()
	game.queue_free()
	await process_frame
	print("CAPTURE_COMBAT_TEST_MODE: PASS")
	quit(0)


func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_ROOT + file_name)
	if error != OK:
		push_error("CAPTURE_COMBAT_TEST_MODE: failed to save %s (%s)" % [file_name, error_string(error)])
