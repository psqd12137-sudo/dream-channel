extends SceneTree

# Optional real-screen capture for the combat presentation lab. It uses a
# dedicated user:// repository so the formal run is never opened or written.
var failures: Array[String] = []
var game: Node3D
var capture_repository


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	capture_repository = load("res://scripts/run_save_repository.gd").new("user://combat_imagination_capture.json", "combat_imagination_capture")
	_check(capture_repository.write({"source": "stale_capture", "interrupted": true}), "capture regression must seed its dedicated stale repository")
	_check(capture_repository.exists(), "capture regression must begin with a stale dedicated repository")
	_check(capture_repository.clear(), "capture lab must clear a stale isolated save before it starts")
	_check(not capture_repository.exists(), "capture lab must clear a stale isolated save before it starts")
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		_finish("SKIP graphical Vulkan display is required")
		return
	game = load("res://channel_3d.tscn").instantiate() as Node3D
	game.animation_duration_scale = 1.0
	game.run_save_repository = capture_repository
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_combat_lab("hall")
	await _capture("imagination-entry")
	await _wait_for_entry()
	game.set_battle_imagination_mode("baseline")
	await _capture("baseline")
	game.set_battle_imagination_mode("imagination")
	await _capture("imagination")
	game.orbit_battle_camera(Vector2(196.0, 0.0))
	await _capture("imagination-rotated")
	_check(not game.run_save_repository.exists(), "capture lab must not create a formal run save")
	game.go_home()
	capture_repository.clear()
	game.queue_free()
	await process_frame
	_finish("PASS baseline imagination rotated entry")


func _finish(success_message: String) -> void:
	if failures.is_empty():
		print("COMBAT_IMAGINATION_CAPTURE: %s" % success_message)
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_IMAGINATION_CAPTURE: %s" % failure)
		quit(1)


func _wait_for_entry() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while game.animation_busy and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not game.animation_busy, "combat imagination entry must settle before capture")


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var texture := root.get_texture()
	_check(texture != null, "%s capture viewport must exist" % label)
	if texture == null:
		return
	var capture_directory := ProjectSettings.globalize_path("res://../output/combat-imagination")
	DirAccess.make_dir_recursive_absolute(capture_directory)
	var path := "%s/%s.png" % [capture_directory, label]
	_check(texture.get_image().save_png(path) == OK, "%s capture saves" % label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
