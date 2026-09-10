extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow = load("res://scripts/solo_stage_flow.gd").new()
	_check(flow != null, "SoloStageFlow can be loaded")
	flow.reset(1337, {"milestones": [4, 8, 12]})
	_check(flow.due_stage(3) == 0, "stage 1 is not due before milestone")
	_check(flow.due_stage(4) == 1, "stage 1 is due at milestone")
	_check(flow.accept_result({"stage": 1, "selected_id": "a"}), "stage 1 accepts one result")
	_check(not flow.accept_result({"stage": 1, "selected_id": "b"}), "stage 1 cannot accept a second result")
	_check(flow.due_stage(8) == 2, "stage 2 is due after stage 1 result")
	_check(flow.accept_result({"stage": 2, "abstained": true}), "stage 2 accepts abstention")
	_check(flow.accept_result({"stage": 3, "selected_id": "c"}), "stage 3 accepts one result")
	_check(flow.is_finale_ready(), "three accepted results enter finale")
	_check(flow.due_stage(12) == 0, "finale has no fourth draw")
	var copy = load("res://scripts/solo_stage_flow.gd").new()
	_check(copy.restore(JSON.parse_string(JSON.stringify(flow.snapshot()))), "snapshot restores through JSON")
	_check(copy.is_finale_ready() and copy.results.size() == 3, "restored finale remains final")
	var atomic_before: Dictionary = copy.snapshot()
	_check(not copy.restore({"version": 1, "stage": 2, "results": [{"stage": 1, "selected_id": "ok"}, {"stage": 2}], "pending_result": {}}), "malformed restore is rejected")
	_check(copy.snapshot() == atomic_before, "failed restore leaves existing state unchanged")
	var invalid = load("res://scripts/solo_stage_flow.gd").new()
	_check(not invalid.restore({"version": 99}), "unknown version is rejected")
	_check(not invalid.restore({"version": 1, "stage": 2, "results": [], "pending_result": {"stage": 1}}), "inconsistent pending result is rejected")
	_check(not invalid.restore({"version": 1, "stage": 3, "results": [{"stage": 2, "selected_id": "a"}, {"stage": 3, "selected_id": "b"}], "pending_result": {}}), "non-sequential result stages are rejected")
	_check(not invalid.restore({"version": 1, "stage": 2, "results": [{"stage": 1}], "pending_result": {}}), "malformed result records are rejected")
	await _run_game_integration()
	if failures.is_empty():
		print("SOLO_STAGE_FLOW: PASS three stages isolated state")
		quit(0)
	else:
		for failure: String in failures:
			push_error("SOLO_STAGE_FLOW: " + failure)
		print("SOLO_STAGE_FLOW: FAIL %d" % failures.size())
		quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run_game_integration() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var formal_repo = load("res://scripts/run_save_repository.gd").new("res://.test_solo_formal.json", game.EXE_SOURCE_ID)
	formal_repo.clear()
	formal_repo.write({"sentinel": 1})
	var formal_before: Dictionary = formal_repo.read()
	game.run_save_repository = formal_repo
	game.go_home()
	game.home_tests_open = true
	game._refresh_hud()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.hud.HOME_TEST_SOLO_STAGE_RECT.get_center() * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	_check(game.solo_stage_trial_active, "HUD backend click starts solo trial")
	_check(game.run_save_repository.save_path == "user://solo_stage_trial_v1.json", "solo trial uses isolated repository")
	_check(game.solo_stage_flow.due_stage(4) == 1, "trial stage 1 milestone is wired")
	game.run_progress = 4
	game.phase = "reward"
	game.reward_origin = "quiet"
	game.set("reward_options", [{"kind": "stat", "id": "heal"}])
	game._finish_reward()
	_check(game.phase == "explore" and game.solo_stage_flow.due_stage(4) == 1, "all reward origins stop at stage 1 draw")
	_check(game.solo_stage_flow.accept_result({"stage": 1, "selected_id": "a"}), "integration accepts stage 1")
	game.run_progress = 8
	game.phase = "reward"
	game.reward_origin = "event"
	game._finish_reward()
	_check(game.phase == "explore" and game.solo_stage_flow.due_stage(8) == 2, "event reward stops at stage 2 draw")
	_check(game.solo_stage_flow.accept_result({"stage": 2, "abstained": true}), "integration accepts stage 2 abstention")
	game.run_progress = 12
	game.phase = "reward"
	game.reward_origin = "boss_access"
	game._finish_reward()
	_check(game.phase == "explore" and game.solo_stage_flow.due_stage(12) == 3, "boss access stops at stage 3 draw")
	game.run_save_repository.write({"version": 1, "source": game.EXE_SOURCE_ID, "seed": 1337, "dream_stage": "malformed"})
	var malformed_loaded: bool = game.continue_saved_run()
	_check(not malformed_loaded and game.run_save_repository.exists(), "malformed dream_stage is rejected without clearing")
	game.run_save_repository.write({"version": 1, "source": game.EXE_SOURCE_ID, "seed": 1337})
	_check(game.continue_saved_run(), "missing dream_stage preserves legacy load path")
	game.go_home()
	_check(formal_repo.read() == formal_before, "formal repository remains unchanged after trial")
	_check(game.run_save_repository == formal_repo, "go home restores formal repository")
	formal_repo.clear()
	game.queue_free()
	await process_frame
