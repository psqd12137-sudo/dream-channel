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
	# 测试使用项目目录内的隔离存档，避免清理/改写用户真实 user:// 存档。
	game.run_save_repository = ChannelRunSaveRepository.new("res://.test_channel_run_v1.json", game.EXE_SOURCE_ID)
	game._clear_run_save()
	game.go_home()
	game.start_new_run(false)
	var first_random_seed: int = game.run_seed
	game.go_home()
	game.start_new_run(false)
	var second_random_seed: int = game.run_seed
	_check(first_random_seed != second_random_seed and first_random_seed > 0 and second_random_seed > 0, "each normal new run must receive a different positive random seed")
	game.reset_run(1)
	var first_layout_profile := str(game.run_layout_profile.get("id", ""))
	game.reset_run(2)
	var second_layout_profile := str(game.run_layout_profile.get("id", ""))
	_check(not first_layout_profile.is_empty() and first_layout_profile != second_layout_profile, "different seeds must select different structural layout profiles")
	game.go_home()
	_check(game.start_run_from_seed_text("2522061406") and game.run_seed == 2522061406, "legacy ten-digit seed codes must remain replayable")
	game.go_home()
	_check(game.start_run_from_seed_text("2026081901"), "a valid seed code must start a reproducible run from the title flow")
	_check(game.run_seed == 2026081901 and int(game.content.get("run_seed", 0)) == game.run_seed, "an explicit seed must keep automated runs reproducible")
	_check(not game.current_layout_profile_label().is_empty(), "a seeded run must expose its structural layout profile")
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
	_check(game.run_seed == 2026081901, "continue must preserve the saved run seed instead of rolling a new one")
	_check(game.run_deck.size() == deck_before + 1, "continue must restore the grown deck")
	_check(game.player_speed == 5 and game.player_hp == 4, "continue must restore persistent player stats")

	game.start_chase_lab()
	_check(game.chase_phase == "ready" and game.chase_sentence.is_empty(), "Web chase must wait in ready before choosing a sentence")
	game.begin_chase()
	_check(game.chase_phase == "countdown" and game.chase_countdown_text == "3", "Web chase countdown must begin at 3")
	game._update_chase(0.75)
	_check(game.chase_countdown_text == "2", "Web chase countdown must advance to 2 after 750 ms")
	game._update_chase(0.75)
	_check(game.chase_countdown_text == "1", "Web chase countdown must advance to 1 after 1500 ms")
	game._update_chase(0.75)
	_check(game.chase_countdown_text == "跑！", "Web chase countdown must show run before the race")
	game._update_chase(0.55)
	_check(game.chase_phase == "race" and game.chase_sentence in game.CHASE_SENTENCES, "Web chase must draw a sentence when the race starts")
	var chase_start: float = game.chase_player_progress
	game._update_chase(1.0)
	_check(is_equal_approx(game.chase_police_progress, game.CHASE_POLICE_SPEED * 0.05), "Web chase race tick must clamp long frames to 50 ms")
	for index in range(game.chase_sentence.length() - 1):
		_send_chase_key(game, game.chase_sentence.substr(index, 1))
	_check(is_equal_approx(game.chase_player_progress, chase_start), "typing chase must advance by completed sentence, not by character")
	_send_chase_key(game, "x")
	_check(game.chase_typed == game.chase_sentence.length() - 1 and game.chase_miss_flash_remaining > 0.0, "mistakes must preserve progress and trigger feedback")
	_send_chase_key(game, game.chase_sentence.right(1))
	_check(game.chase_result == "success", "typing the full sentence must finish the chase")
	_check(is_equal_approx(game.chase_player_progress, game.CHASE_TRACK_LENGTH), "a completed sentence must carry the player to the exit")

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


func _send_chase_key(game: Node3D, character: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = character.unicode_at(0)
	game.hud._input(event)
