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
	var formal_snapshot := {
		"seed": game.run_seed,
		"hp": game.player_hp,
		"max_hp": game.player_max_hp,
		"speed": game.player_speed,
		"progress": game.run_progress,
		"deck": game.run_deck.duplicate(),
		"room_pos": game.current_room_pos,
		"placed": game.room_rules.placed.duplicate(true),
		"event_context": game.event_context,
		"rewards": game.reward_options.duplicate(true),
	}
	game.open_combat_test_mode()
	game.select_combat_test_scenario("portal_trap_height")
	_check(game.start_test_combat("observer_step"), "isolation scenario must start")
	game.advance_test_observer()
	await process_frame
	game.return_to_combat_test_menu()
	_check(game.phase == "test_combat_menu", "isolation test must return to the test desk")
	_check(not game.test_combat_active and game.combat == null, "test combat must be discarded")
	_check(game.run_seed == formal_snapshot.seed, "test seed must not leak into formal state")
	_check(game.player_hp == formal_snapshot.hp and game.player_max_hp == formal_snapshot.max_hp, "test HP must not leak into formal state")
	_check(game.player_speed == formal_snapshot.speed, "test speed must not leak into formal state")
	_check(game.run_progress == formal_snapshot.progress, "test combat must not advance formal progress")
	_check(game.run_deck == formal_snapshot.deck, "test deck must not leak into formal state")
	_check(game.current_room_pos == formal_snapshot.room_pos, "test room must not change formal room position")
	_check(game.room_rules.placed == formal_snapshot.placed, "test room must not mutate formal room placement")
	_check(game.event_context == formal_snapshot.event_context, "test combat must not mutate event context")
	_check(game.reward_options == formal_snapshot.rewards, "test combat must not create formal rewards")
	game.go_home()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_COMBAT_TEST_ISOLATION: PASS-formal-state-restored")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_COMBAT_TEST_ISOLATION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
