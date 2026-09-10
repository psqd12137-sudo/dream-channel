extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	game.solo_stage_trial_active = true
	game.solo_stage_trial_config = {"milestones": [4, 8, 12]}
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://solo_three_stage_flow_regression.json", game.EXE_SOURCE_ID)
	game.run_save_repository.clear()
	game.start_new_run(false, 20260911)
	game.choose_omen(0)
	game.room_rules.placed.clear()
	for index in range(5):
		var room_id := "room-%s" % ("abc"[index] if index < 3 else str(index))
		game.room_rules.placed[Vector2i(index, 0)] = {
			"id": room_id,
			"name": room_id,
			"kind": "combat" if index == 1 or index == 2 else "quiet",
			"room_size": 3 if index == 0 else 1,
			"doors": [true, true, true, true],
			"origin": [index, 0],
			"instance_id": "%s@%d,0" % [room_id, index],
			"revealed": true,
			"completed": true,
			"visited": true,
		}
	game.current_room_pos = Vector2i.ZERO
	game.room_ledger = load("res://scripts/dream_room_ledger.gd").new()
	game.room_ledger.visit({"instance_id": "source-a", "room_id": "room-a", "name": "A", "room_size": 3, "kind": "quiet", "visited": true})
	game.room_ledger.visit({"instance_id": "source-b", "room_id": "room-b", "name": "B", "room_size": 1, "kind": "combat", "visited": true})
	game.room_ledger.visit({"instance_id": "source-c", "room_id": "room-c", "name": "C", "room_size": 1, "kind": "combat", "visited": true})
	for result in [
		{"stage": 1, "selected_id": "source-a"},
		{"stage": 2, "selected_id": "source-b"},
		{"stage": 3, "selected_id": "source-c"},
	]:
		_check(game.solo_stage_flow.accept_result(result), "三阶段结果应按顺序接受")
	game.dream_program_available = true
	game.dream_program_handoff = {"type": "dream_finale_program", "source_ids": ["source-a", "source-b", "source-c"]}
	game.open_dream_program(game.dream_program_handoff)
	_check(game.phase == "boss_ready", "打开第三阶段节目单后进入 boss_ready")
	_check(game.boss_id == "channel_host", "单人终幕使用固定 Boss")
	_check(str(game.dream_finale_profile.get("route_rule", "")) == "long_charge", "节目单打开时生成终幕 profile")
	game.begin_boss_combat()
	_check(game.phase == "world_boss" and game.combat != null, "boss_ready 可以开始终幕战斗")
	if game.combat != null:
		_check(game.combat.initial.get("rules", {}).get("dream_finale_profile", {}).get("climax_rule", "") == "double_sweep", "Boss combat initial rules 保留终幕 profile")
	game._save_run()
	var saved: Dictionary = game.run_save_repository.read()
	_check(saved.get("dream_finale_profile", {}).get("source_ids", []) == ["source-a", "source-b", "source-c"], "终幕 profile 写入运行存档")
	game.go_home()
	var resumed = load("res://channel_3d.tscn").instantiate()
	resumed.animation_duration_scale = 0.0
	root.add_child(resumed)
	await process_frame
	resumed.solo_stage_trial_active = true
	resumed.solo_stage_trial_config = {"milestones": [4, 8, 12]}
	resumed.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://solo_three_stage_flow_regression.json", resumed.EXE_SOURCE_ID)
	_check(resumed.continue_saved_run(), "终幕战斗存档应可恢复")
	_check(resumed.phase == "world_boss" and str(resumed.dream_finale_profile.get("climax_rule", "")) == "double_sweep", "恢复后继续使用同一终幕 profile")
	resumed.go_home()
	game.run_save_repository.clear()
	game.queue_free()
	resumed.queue_free()
	await process_frame
	if failures.is_empty():
		print("SOLO_THREE_STAGE_FLOW: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("SOLO_THREE_STAGE_FLOW: " + failure)
		print("SOLO_THREE_STAGE_FLOW: FAIL %d" % failures.size())
		quit(1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
