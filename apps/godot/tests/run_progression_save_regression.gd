extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game._clear_run_save()
	game.start_new_run(false)
	game.choose_omen(0)
	_check(game.run_deck.size() == game.content.get("starter_deck", []).size(), "new run must own a persistent copy of the Web starter deck")
	game.player_hp = 3
	game.player_max_hp = 6
	var progress_before: int = game.run_progress
	game._complete_current_room()
	game._start_quiet_reward()
	_check(game.phase == "reward", "quiet room must open the growth reward stage")
	_check(game.player_hp == 4, "quiet room must grant its once-per-room breath heal")
	game.choose_reward(0)
	_check(game.phase == "explore", "choosing a quiet reward must return to exploration")
	_check(game.player_hp == 6, "heal reward must apply after the quiet breath heal")
	_check(game.run_progress == progress_before, "already completed foyer must not advance twice")

	var deck_before: int = game.run_deck.size()
	game._start_card_reward("test")
	_check(game.reward_options.size() == 3, "combat reward must offer three Web cards")
	game._save_run()
	game.go_home()
	_check(game.continue_saved_run() and game.phase == "reward" and game.reward_options.size() == 3, "continue during a reward must restore the pending choices")
	game.choose_reward(0)
	_check(game.run_deck.size() == deck_before + 1, "chosen combat reward must persist in the run deck")

	game.player_speed = 5
	game.player_hp = 4
	game._save_run()
	game.go_home()
	_check(game.has_saved_run(), "home screen must detect the saved episode")
	game.run_deck.clear()
	game.player_speed = 1
	_check(game.continue_saved_run(), "continue must restore a compatible EXE-based save")
	_check(game.run_deck.size() == deck_before + 1, "continue must restore the grown deck")
	_check(game.player_speed == 5 and game.player_hp == 4, "continue must restore persistent player stats")

	game.start_chase_lab()
	game.begin_chase()
	game.chase_countdown = 0.0
	for character in game.chase_sentence:
		game.chase_type_character(character)
	_check(game.chase_result == "success", "typing the full sentence must finish the chase")

	game._clear_run_save()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_RUN_PROGRESSION_SAVE: PASS deck reward quiet save continue chase")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_RUN_PROGRESSION_SAVE: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
