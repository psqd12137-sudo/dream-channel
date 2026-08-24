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
	game.animation_duration_scale = 0.0
	game.open_combat_test_mode()
	game.select_combat_test_scenario("squad_roles")
	_check(game.start_test_combat("observer_auto"), "auto observer must start")
	for _i in range(14):
		await process_frame
	_check(game.test_session.round_count == 10, "auto observer must stop at the ten-round scenario limit")
	_check(game.test_session.paused, "auto observer must pause at the round limit")
	_check(game.test_session.last_summary.get("scenario_id", "") == "squad_roles", "observer must keep a reproducible summary")
	_check(game.test_session.anomalies.is_empty(), "observer events must not produce anomalies: %s" % str(game.test_session.anomalies))
	game.return_to_combat_test_menu()
	game.select_combat_test_scenario("baseline_single")
	_check(game.start_test_combat("observer_step"), "step observer must start")
	game.advance_test_observer()
	await process_frame
	_check(game.test_session.round_count == 1, "step observer must advance exactly one enemy phase")
	_check(game.test_session.paused, "step observer must pause after one phase")
	game.restart_test_combat()
	_check(game.test_session.round_count == 0 and game.combat.round_number == 1, "restart must restore the initial observer state")
	game.return_to_combat_test_menu()
	game.go_home()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_COMBAT_TEST_OBSERVER: PASS auto-ten-round-step-pause-restart")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_TEST_OBSERVER: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
