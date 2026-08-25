extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://channel_3d.tscn")
	var game: Node3D = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_check(game.open_combat_test_mode(), "backend test desk must open")
	_check(game.test_catalog.get_scenario("pixel_art_showcase").size() > 0, "pixel showcase scenario must be registered")
	game.select_combat_test_scenario("pixel_art_showcase")
	_check(game.start_test_combat("manual"), "pixel showcase scenario must start")
	await process_frame
	_check(game.phase == "combat", "pixel showcase must enter combat")
	_check(game.active_test_visual_filter_id == "pixel_art_3d", "pixel showcase must activate its declared filter")
	var pixel_material := game.world_container.material as ShaderMaterial
	_check(pixel_material != null, "pixel showcase must use a shader material")
	_check(pixel_material.shader != null and pixel_material.shader.resource_path.ends_with("pixel_art_3d.gdshader"), "pixel showcase must use the pixel shader")

	game.return_to_combat_test_menu()
	_check(game.active_test_visual_filter_id == "", "returning to the test desk must clear the level filter")
	var restored_material := game.world_container.material as ShaderMaterial
	_check(restored_material != null and restored_material.shader != null and restored_material.shader.resource_path.ends_with("tilt_shift_miniature.gdshader"), "returning to the test desk must restore the default filter")

	game.select_combat_test_scenario("baseline_single")
	_check(game.start_test_combat("manual"), "baseline scenario must still start")
	await process_frame
	_check(game.active_test_visual_filter_id == "", "baseline scenario must not inherit the pixel filter")

	game.go_home()
	_check(game.active_test_visual_filter_id == "", "formal flow must not retain the test filter")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PIXEL_FILTER_REGRESSION: PASS scenario-scope-and-reset")
		quit(0)
	else:
		for failure: String in failures:
			push_error("PIXEL_FILTER_REGRESSION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
