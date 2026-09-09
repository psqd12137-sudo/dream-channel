extends SceneTree

var failures: Array[String] = []
var game: Node3D
var save_repository
var capture := "--capture" in OS.get_cmdline_user_args()

func _init() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	save_repository = load("res://scripts/run_save_repository.gd").new("user://wall_transition_lab_test.json", game.EXE_SOURCE_ID)
	game.run_save_repository = save_repository
	root.add_child(game)
	await process_frame
	await process_frame
	game.toggle_home_tests()
	game.start_wall_transition_lab()
	await process_frame
	await process_frame
	_check(game.phase == "lab_wall_transition", "wall transition lab opens from the test area")
	_check(game.room_rules.placed.has(game.current_room_pos) and game.current_room_pos != Vector2i.ZERO, "wall transition lab creates a deterministic formal-room extension")
	_check(game.house_root.visible and game.world_container.visible and not game.battle_root.visible, "wall transition lab shows the formal house")
	_check(not save_repository.exists(), "wall transition lab does not write a formal run save")
	if capture and root.get_texture() != null:
		var capture_path := ProjectSettings.globalize_path("res://../output/wall-transition-lab-entry.png")
		var capture_error := root.get_texture().get_image().save_png(capture_path)
		_check(capture_error == OK, "wall transition lab capture saves")
	var composer := game.house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	_check(composer != null, "wall transition lab uses the formal composer")
	if composer != null:
		_check(int(composer.cutaway_transition_state().get("mode", -1)) == 0, "wall transition lab starts in instant mode")
		game.set_wall_transition_lab_mode(1)
		await create_timer(0.30).timeout
		_check(int(composer.cutaway_transition_state().get("mode", -1)) == 1, "wall transition lab switches to retract mode")
		game.set_wall_transition_lab_mode(2)
		await create_timer(0.30).timeout
		_check(int(composer.cutaway_transition_state().get("mode", -1)) == 2, "wall transition lab switches to wave mode")
	game.go_home()
	await process_frame
	_check(game.phase == "home", "wall transition lab exits to title")
	_check(not save_repository.exists(), "wall transition lab exit keeps formal save untouched")
	save_repository.clear()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("WALL_TRANSITION_LAB: PASS menu-entry formal-scene mode-switch save-isolation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("WALL_TRANSITION_LAB: " + failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
