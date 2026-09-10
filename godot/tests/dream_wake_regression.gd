extends SceneTree

var failures: Array[String] = []
var finished_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation_script = load("res://scripts/dream_wake_presentation.gd")
	_check(presentation_script != null, "dream wake presentation script must exist")
	if presentation_script == null:
		_fail_and_quit()
		return

	var presentation = presentation_script.new()
	presentation.skip_seconds = 0.0
	root.add_child(presentation)
	await process_frame
	presentation.finished.connect(func() -> void: finished_count += 1)
	var player := Node3D.new()
	player.name = "TestToy"
	root.add_child(player)
	var victory_recap := {
		"outcome": "victory",
		"success": true,
		"title": "梦演到结尾",
		"cards": [
			{"name": "长廊", "hp_lost": 2},
			{"name": "厨房", "hp_lost": 0},
			{"name": "阁楼", "hp_lost": 4},
		]
	}
	presentation.play(player, victory_recap, 2.0)
	_check(presentation.is_playing(), "presentation enters playing state")
	_check(presentation.input_locked, "presentation locks input while cards play")
	_check(presentation.current_outcome == "victory", "presentation keeps the real victory outcome")
	_check(presentation.card_count() == 3, "presentation keeps three recap cards")
	_check(not presentation.has_ranking_or_opponent_copy(), "presentation has no ranking or virtual opponents")
	presentation.skip()
	presentation.skip()
	await process_frame
	_check(finished_count == 1, "repeated skip emits finished exactly once")
	_check(not presentation.input_locked, "finished presentation unlocks input")
	_check(not presentation.is_playing(), "finished presentation leaves playing state")
	_check(presentation.player_was_stilled, "presentation stills the toy before the coda")

	# The entrance and ending use the same card reel. Each third of its duration
	# must promote exactly one material so the spotlight has a readable rhythm.
	presentation.play(player, {"outcome": "program_intro", "cards": victory_recap.cards}, 0.9)
	_check(presentation.active_card_index == 0, "reel starts with the first material")
	await process_frame
	_check(presentation.active_card_index == 0, "first material remains lit at the first frame")
	await create_timer(0.35).timeout
	await process_frame
	_check(presentation.active_card_index == 1, "reel promotes the second material after one third")
	await create_timer(0.35).timeout
	await process_frame
	_check(presentation.active_card_index == 2, "reel promotes the third material after two thirds")
	presentation.skip()
	presentation.skip()
	await process_frame
	_check(finished_count == 2, "intro reel skip remains idempotent")

	# A defeat must not inherit the success copy, and a missing actor still gets
	# the same deterministic coda.
	presentation.play(null, {
		"outcome": "defeat",
		"success": false,
		"title": "梦提前中断",
		"cards": [{"name": "地下室", "hp_lost": 6}],
	}, 0.0)
	_check(presentation.current_outcome == "defeat", "presentation keeps the real defeat outcome")
	_check(not presentation.current_recap.get("success", true), "defeat recap cannot be rendered as success")
	presentation.skip()
	await process_frame
	_check(finished_count == 3, "missing player node still completes the coda once")
	_check(not presentation.input_locked, "missing player node does not leave input locked")

	# Exercise the real Boss handoff as a persisted ending. The preview uses the
	# production overworld and is redirected to a disposable run repository.
	var game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://dream_wake_regression_run.json", game.EXE_SOURCE_ID)
	game.run_save_repository.clear()
	game.start_host_preview()
	game.boss_preview_active = false
	game.begin_boss_combat()
	_check(game.combat != null, "production Boss setup reaches the final combat")
	if game.combat != null:
		game.combat.outcome = "victory"
		game.return_from_combat()
	_check(game.phase == "ending" and game.ending_pending, "Boss result saves a pending ending before the coda")
	_check(game.run_save_repository.read().get("ending_outcome", "") == "victory", "saved ending keeps the real victory outcome")
	await process_frame
	_check(not game.dream_wake_presentation.input_locked, "production coda unlocks input after playback")
	var resumed = load("res://channel_3d.tscn").instantiate()
	resumed.animation_duration_scale = 0.0
	root.add_child(resumed)
	await process_frame
	resumed.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://dream_wake_regression_run.json", resumed.EXE_SOURCE_ID)
	_check(resumed.continue_saved_run(), "pending ending can be resumed after an exit")
	_check(resumed.phase == "ending" and resumed.ending_outcome == "victory", "resume shows the same saved ending")
	await process_frame
	resumed.finish_ending()
	_check(resumed.phase == "home" and not resumed.run_save_repository.exists(), "confirming the ending clears the isolated run save")
	game.queue_free()
	resumed.queue_free()
	await process_frame

	presentation.queue_free()
	player.queue_free()
	await process_frame
	_fail_and_quit()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _fail_and_quit() -> void:
	if failures.is_empty():
		print("DREAM_WAKE: PASS")
		quit(0)
		return
	for failure: String in failures:
		push_error("DREAM_WAKE: " + failure)
	print("DREAM_WAKE: FAIL %d" % failures.size())
	quit(1)
