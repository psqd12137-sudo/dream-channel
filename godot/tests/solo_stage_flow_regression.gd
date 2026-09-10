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
	var first = load("res://scripts/solo_stage_flow.gd").new()
	var second = load("res://scripts/solo_stage_flow.gd").new()
	first.reset(20260916, {"milestones": [4, 8, 12]})
	second.reset(20260916, {"milestones": [4, 8, 12]})
	var exploration_rng := RandomNumberGenerator.new()
	exploration_rng.seed = 777
	var first_rolls: Array[float] = []
	var second_rolls: Array[float] = []
	for index in range(3):
		first_rolls.append(first.next_draw_roll())
		for noise in range(index + 1):
			exploration_rng.randf()
		second_rolls.append(second.next_draw_roll())
	_check(first_rolls == second_rolls, "探索 RNG 消费不改变独立梦境抽片序列")
	var restored = load("res://scripts/solo_stage_flow.gd").new()
	_check(restored.restore(first.snapshot()), "独立梦境 RNG 状态可恢复")
	_check(is_equal_approx(restored.next_draw_roll(), first.next_draw_roll()), "独立梦境 RNG 恢复后继续同一序列")
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
	# A checkpoint taken after the draw result is committed must resume in the
	# reveal-only state and clear pending exactly once, without reopening choices.
	var pending_path := "res://.test_solo_pending_draw.json"
	var pending_game = load("res://channel_3d.tscn").instantiate()
	pending_game.animation_duration_scale = 0.0
	root.add_child(pending_game)
	await process_frame
	pending_game.run_save_repository = load("res://scripts/run_save_repository.gd").new(pending_path, pending_game.EXE_SOURCE_ID)
	pending_game.run_save_repository.clear()
	pending_game.solo_stage_trial_active = true
	pending_game.solo_stage_trial_config = pending_game._load_json_dictionary(pending_game.SOLO_STAGE_TRIAL_DATA_PATH)
	pending_game.start_new_run(false, 20260910)
	pending_game.room_ledger.visit({"instance_id": "pending-a", "room_id": "kitchen", "name": "厨房", "visited": true})
	pending_game.room_ledger.visit({"instance_id": "pending-b", "room_id": "hall", "name": "走廊", "visited": true})
	pending_game.dream_draw_active = true
	pending_game.dream_draw_stage = 1
	_check(pending_game.solo_stage_flow.accept_result({"stage": 1, "selected_id": "pending-b", "nomination_id": "pending-a", "probabilities": {"pending-a": 0.6, "pending-b": 0.4}, "roll": 0.2}), "pending draw checkpoint is accepted")
	pending_game._save_run()
	var resumed = load("res://channel_3d.tscn").instantiate()
	resumed.animation_duration_scale = 0.0
	root.add_child(resumed)
	await process_frame
	resumed.run_save_repository = load("res://scripts/run_save_repository.gd").new(pending_path, resumed.EXE_SOURCE_ID)
	resumed.solo_stage_trial_active = true
	resumed.solo_stage_trial_config = resumed._load_json_dictionary(resumed.SOLO_STAGE_TRIAL_DATA_PATH)
	_check(resumed.continue_saved_run(), "pending draw checkpoint restores")
	await process_frame
	_check(resumed.solo_stage_flow.results.size() == 1 and resumed.solo_stage_flow.pending_result.is_empty(), "pending result is cleared after one reveal")
	_check(not resumed.dream_draw_active, "restored pending draw does not reopen nomination")
	_check(resumed.hud.dream_stage_panel.visible and resumed.hud.dream_stage_panel.get_node_or_null("ContinueRecap") != null, "reveal-only panel keeps a readable recap before continuing")
	resumed.hud.dream_stage_panel.get_node_or_null("ContinueRecap").emit_signal("pressed")
	_check(not resumed.hud.dream_stage_panel.visible, "recap continue closes the panel")
	pending_game.queue_free()
	resumed.queue_free()
	FileAccess.open(pending_path, FileAccess.WRITE).store_string("")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_path))
	game.go_home()
	_check(formal_repo.read() == formal_before, "formal repository remains unchanged after trial")
	_check(game.run_save_repository == formal_repo, "go home restores formal repository")
	formal_repo.clear()
	game.queue_free()
	await process_frame
