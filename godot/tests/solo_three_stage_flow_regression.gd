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
	for index in range(6):
		var room_id := "room-%s" % ("abcd"[index] if index < 4 else str(index))
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
	game.room_ledger.visit({"instance_id": "source-d", "room_id": "room-d", "name": "D", "room_size": 1, "kind": "quiet", "visited": true})
	for stage_data in [
		{"progress": 4, "origin": "quiet", "nomination": "source-a"},
		{"progress": 8, "origin": "event", "nomination": "source-b"},
		{"progress": 12, "origin": "quiet", "nomination": "source-c"},
	]:
		game.run_progress = int(stage_data.progress)
		game.phase = "reward"
		game.reward_origin = str(stage_data.origin)
		game.reward_options.clear()
		game.reward_options.append({"kind": "stat", "id": "heal"})
		game._finish_reward()
		_check(game.dream_draw_active, "阶段奖励完成后打开抽片面板")
		var excluded: Array[String] = []
		for accepted: Dictionary in game.solo_stage_flow.results:
			var selected_id := str(accepted.get("selected_id", ""))
			if not selected_id.is_empty():
				excluded.append(selected_id)
		var available: Array[Dictionary] = game.room_ledger.candidates(excluded)
		var nomination := str(stage_data.nomination)
		if not available.any(func(record: Dictionary) -> bool: return str(record.get("instance_id", "")) == nomination):
			nomination = str(available[0].get("instance_id", "")) if not available.is_empty() else ""
		# Exercise the same panel callback used by the live HUD.
		game.hud._on_dream_stage_submitted(nomination)
		_check(game.solo_stage_flow.pending_result.has("selected_id"), "阶段提名后生成待揭晓结果")
		game.hud._on_dream_stage_reveal_finished()
		_check(not game.dream_draw_active, "阶段揭晓完成后关闭抽片状态")
	_check(game.solo_stage_flow.is_finale_ready(), "三次奖励抽片后进入终幕素材完成状态")
	game.hud._on_dream_program_requested(game.dream_program_handoff)
	_check(game.phase == "boss_ready", "打开第三阶段节目单后进入 boss_ready")
	_check(game.boss_id == "channel_host", "单人终幕使用固定 Boss")
	_check(str(game.dream_finale_profile.get("route_rule", "")) in ["long_charge", "short_charge"], "节目单打开时生成终幕 profile")
	var source_names: Array = game.dream_program_handoff.get("source_names", [])
	var mapping_has_names := true
	for raw_source_name: Variant in source_names:
		mapping_has_names = mapping_has_names and game.hud.dream_stage_panel._message.contains(str(raw_source_name))
	_check(source_names.size() == 3 and mapping_has_names, "节目单映射显示真实房间名称")
	game.begin_boss_combat()
	_check(game.phase == "world_boss" and game.combat != null, "boss_ready 可以开始终幕战斗")
	if game.combat != null:
		_check(game.combat.initial.get("rules", {}).get("dream_finale_profile", {}).get("source_ids", []) == game.dream_finale_profile.get("source_ids", []), "Boss combat initial rules 保留终幕 profile")
	var expected_profile: Dictionary = game.dream_finale_profile.duplicate(true)
	game._save_run()
	var saved: Dictionary = game.run_save_repository.read()
	_check(saved.get("dream_finale_profile", {}).get("source_ids", []) == game.dream_finale_profile.get("source_ids", []), "终幕 profile 写入运行存档")
	game.go_home()
	var resumed = load("res://channel_3d.tscn").instantiate()
	resumed.animation_duration_scale = 0.0
	root.add_child(resumed)
	await process_frame
	resumed.solo_stage_trial_active = true
	resumed.solo_stage_trial_config = {"milestones": [4, 8, 12]}
	resumed.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://solo_three_stage_flow_regression.json", resumed.EXE_SOURCE_ID)
	_check(resumed.continue_saved_run(), "终幕战斗存档应可恢复")
	_check(resumed.phase == "world_boss" and resumed.dream_finale_profile.get("source_ids", []) == expected_profile.get("source_ids", []) and resumed.dream_finale_profile.get("route_rule", "") == expected_profile.get("route_rule", "") and resumed.dream_finale_profile.get("climax_rule", "") == expected_profile.get("climax_rule", ""), "恢复后继续使用同一终幕 profile")
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
