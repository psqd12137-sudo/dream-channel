extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	# The formal repository is observed only. Every write below targets an
	# isolated trial repository, so the test can prove the sample boundary
	# without installing a sentinel into the user's real save.
	var formal_path := str(game.RUN_SAVE_PATH)
	var formal_existed_before := FileAccess.file_exists(formal_path)
	var formal_fingerprint_before: PackedByteArray = _file_fingerprint(formal_path) if formal_existed_before else PackedByteArray()
	var trial_path := "user://solo_three_stage_flow_regression.json"
	var abstain_path := "user://solo_three_stage_flow_regression_abstain.json"
	_check(formal_path != trial_path and formal_path != abstain_path and trial_path != abstain_path, "formal and sample repositories remain isolated")
	game.solo_stage_trial_active = true
	game.solo_stage_trial_config = {"milestones": [4, 8, 12]}
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new(trial_path, game.EXE_SOURCE_ID)
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
		var persisted: Dictionary = game.run_save_repository.read()
		var persisted_stage: Variant = persisted.get("dream_stage", {})
		_check(persisted_stage is Dictionary and (persisted_stage as Dictionary).get("results", []).size() == game.solo_stage_flow.results.size(), "阶段结果在每次揭晓后持久化")
		var restored_flow = load("res://scripts/solo_stage_flow.gd").new()
		_check(persisted_stage is Dictionary and restored_flow.restore(persisted_stage as Dictionary), "阶段结果可从存档恢复")
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
	game.animation_duration_scale = 1.0
	game.begin_boss_combat()
	_check(game.phase == "boss_ready" and game.dream_intro_pending, "节目单确认后先进入 Boss 入场演出")
	_check(game.dream_wake_presentation.current_outcome == "program_intro" and game.dream_wake_presentation.active_card_index == 0, "Boss 入场演出从第一张素材开始")
	_check(game.run_save_repository.read().get("dream_intro_pending", false), "Boss 入场演出状态写入运行存档")
	game.dream_wake_presentation.skip()
	_check(game.phase == "world_boss" and game.combat != null and not game.dream_intro_pending, "Boss 入场演出完成后才开始终幕战斗")
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
	game.queue_free()
	resumed.queue_free()
	await process_frame
	await _run_all_abstain_variant(abstain_path)
	await _run_candidate_shortage_variant("user://solo_three_stage_flow_regression_shortage.json")
	await _run_sample_defeat_variant("user://solo_three_stage_flow_regression_defeat.json")
	_check(FileAccess.file_exists(formal_path) == formal_existed_before, "sample runs do not create or remove the formal save")
	_check((not formal_existed_before) or _file_fingerprint(formal_path) == formal_fingerprint_before, "formal save byte fingerprint is unchanged after sample runs")
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


func _new_trial_game(save_path: String, seed_value: int) -> Node:
	var trial = load("res://channel_3d.tscn").instantiate()
	trial.animation_duration_scale = 0.0
	root.add_child(trial)
	await process_frame
	trial.solo_stage_trial_active = true
	trial.solo_stage_trial_config = {"milestones": [4, 8, 12]}
	trial.run_save_repository = load("res://scripts/run_save_repository.gd").new(save_path, trial.EXE_SOURCE_ID)
	trial.run_save_repository.clear()
	trial.start_new_run(false, seed_value)
	trial.choose_omen(0)
	trial.room_ledger = load("res://scripts/dream_room_ledger.gd").new()
	for index in range(4):
		trial.room_ledger.visit({
			"instance_id": "trial-%s" % index,
			"room_id": "trial-room-%s" % index,
			"name": "样片房间 %s" % index,
			"kind": "combat" if index == 1 else "quiet",
			"room_size": 3 if index == 0 else 1,
			"visited": true,
		})
	return trial


func _finish_simulated_reward(trial: Node, progress: int, origin: String = "quiet") -> void:
	# Stage progression intentionally simulates the reward callback. Combat
	# engine behavior is covered separately by the real final Boss setup and
	# the ordinary-room defeat helper below.
	trial.run_progress = progress
	trial.phase = "reward"
	trial.reward_origin = origin
	trial.reward_options.clear()
	trial.reward_options.append({"kind": "stat", "id": "heal"})
	trial._finish_reward()


func _run_all_abstain_variant(save_path: String) -> void:
	var trial = await _new_trial_game(save_path, 20260912)
	for progress in [4, 8, 12]:
		_finish_simulated_reward(trial, progress)
		_check(trial.dream_draw_active, "弃权样片在阶段 %d 打开抽片面板" % (trial.solo_stage_flow.results.size() + 1))
		trial.hud._on_dream_stage_submitted("")
		_check(trial.solo_stage_flow.pending_result.get("abstained", false), "弃权仍生成可回顾的抽片结果")
		trial.hud._on_dream_stage_reveal_finished()
		_check(not trial.dream_draw_active, "弃权揭晓后继续探索")
	_check(trial.solo_stage_flow.is_finale_ready(), "连续三次弃权仍能完成三阶段样片")
	_check(trial.solo_stage_flow.results.all(func(result: Dictionary) -> bool: return bool(result.get("abstained", false))), "三次弃权均写入阶段结果")
	trial.go_home()
	trial.queue_free()
	await process_frame


func _run_candidate_shortage_variant(save_path: String) -> void:
	var trial = await _new_trial_game(save_path, 20260913)
	trial.room_ledger = load("res://scripts/dream_room_ledger.gd").new()
	trial.room_ledger.visit({"instance_id": "only", "room_id": "only-room", "name": "唯一房间", "visited": true})
	_finish_simulated_reward(trial, 4)
	_check(not trial.dream_draw_active and trial.phase == "explore", "候选不足时暂缓抽片并允许继续探索")
	_check(trial.status_message.contains("再探索一间"), "候选不足提示明确要求继续探索")
	trial.room_ledger.visit({"instance_id": "second", "room_id": "second-room", "name": "第二房间", "visited": true})
	_finish_simulated_reward(trial, 4)
	_check(trial.dream_draw_active, "候选补足后阶段抽片可以恢复")
	trial.hud._on_dream_stage_submitted("")
	trial.hud._on_dream_stage_reveal_finished()
	_check(trial.solo_stage_flow.results.size() == 1, "候选补足后只提交一次阶段结果")
	trial.go_home()
	trial.queue_free()
	await process_frame


func _run_sample_defeat_variant(save_path: String) -> void:
	var trial = await _new_trial_game(save_path, 20260914)
	var combat_room: Dictionary = {}
	for candidate: Dictionary in trial.room_catalog:
		if str(candidate.get("kind", "")) == "combat":
			combat_room = candidate.duplicate(true)
			break
	_check(not combat_room.is_empty(), "样片失败验证取得普通战斗房")
	var target := Vector2i(1, 0)
	combat_room["instance_id"] = "defeat-room@1,0"
	combat_room["visited"] = false
	combat_room["revealed"] = false
	combat_room["completed"] = false
	trial.room_rules.placed[target] = combat_room
	trial.current_room_pos = target
	trial._finish_enter_room(target)
	trial.resolve_current_room()
	_check(trial.combat != null and trial.phase == "combat", "普通失败验证走真实战斗入口")
	if trial.combat != null:
		# This is a deterministic failure injection through the combat engine's
		# actual enemy-hit path; stage progression itself remains simulated.
		var enemy = trial.combat.enemy_by_id(trial.combat.enemy_order[0])
		trial.combat._apply_player_hit(enemy, "melee", 999)
		_check(trial.combat.outcome == "defeat", "真实战斗引擎记录致命攻击")
		trial.return_from_combat()
	_check(trial.phase == "explore", "样片普通房失败后继续探索")
	_check(trial.player_hp == ceili(float(trial.player_max_hp) * 0.5), "样片普通房失败恢复到一半生命")
	_check(bool(trial.room_rules.placed[target].get("completed", false)), "样片普通房失败只完成一次房间")
	var progress_after_defeat := int(trial.run_progress)
	trial.return_from_combat()
	_check(int(trial.run_progress) == progress_after_defeat, "样片普通房失败不能重复刷进度")
	trial.go_home()
	trial.queue_free()
	await process_frame


func _file_fingerprint(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	# Godot's PackedByteArray is immutable for this read. Comparing the full
	# byte fingerprint avoids mutating or writing the formal save in this test.
	return FileAccess.get_file_as_bytes(path)
