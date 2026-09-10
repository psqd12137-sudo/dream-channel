extends SceneTree

var failures: Array[String] = []
var submitted_value := "unset"
var revealed_count := 0
var requested_program: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel = load("res://scripts/dream_stage_panel.gd").new()
	root.add_child(panel)
	panel.size = Vector2(1280, 800)
	panel.submitted.connect(func(id: String) -> void: submitted_value = id)
	panel.reveal_finished.connect(func() -> void: revealed_count += 1)
	panel.program_requested.connect(func(entry: Dictionary) -> void: requested_program = entry.duplicate(true))
	var rows: Array[Dictionary] = [
		{"instance_id": "a", "name": "厨房", "hp_lost": 3, "rarity_rank": 1, "difficulty_rank": 1},
		{"instance_id": "b", "name": "客厅", "hp_lost": 0, "rarity_rank": 2, "difficulty_rank": 0}]
	panel.show_candidates(1, rows, {"a": 0.7, "b": 0.3})
	_check(panel.visible, "panel becomes visible with candidates")
	_check(panel.get_node_or_null("Nominate_a") != null and panel.get_node_or_null("Nominate_b") != null, "candidate buttons show room choices")
	_check(panel.get_node_or_null("Nominate_a").text.contains("受伤经历") and panel.get_node_or_null("Nominate_a").text.contains("信物分"), "candidate explains damage and token value")
	_check(not panel.get_node_or_null("Nominate_a").text.contains("金币") and not panel.get_node_or_null("Nominate_a").text.contains("对手"), "panel avoids opponent and coin language")
	_check(panel.get_node_or_null("Nominate_a").text.contains("交给节目") and panel.get_node_or_null("Nominate_a").text.contains("暂无缩略图"), "candidate action and image fallback are explicit")
	panel.update_probabilities({"a": 0.9, "b": 0.1})
	_check(panel.get_node_or_null("Nominate_a").text.contains("90.0%"), "nomination refreshes the visible boosted probability")
	panel.get_node_or_null("Nominate_a").emit_signal("pressed")
	_check(submitted_value == "a", "candidate submission emits instance id")
	panel.reveal({"stage": 1, "selected_id": "b", "probabilities": {"a": 0.7, "b": 0.3}}, 0.0)
	panel.skip_reveal()
	panel.skip_reveal()
	_check(revealed_count == 1, "reveal completion is emitted once even when skipped repeatedly")
	_check(panel._message.contains("阶段素材提示"), "stage one recap explains its material handoff")
	panel.show_candidates(3, rows, {"a": 0.7, "b": 0.3})
	panel._submit("b")
	panel.reveal({"stage": 3, "selected_id": "b", "program_entry": {"type": "dream_finale_program", "source_ids": ["a", "b", "c"]}}, 0.0)
	_check(panel._message.contains("节目单入口"), "stage three recap exposes the program entry")
	_check(panel.get_node_or_null("OpenProgramList").visible, "stage three exposes an actual program list button")
	panel.get_node_or_null("OpenProgramList").emit_signal("pressed")
	_check(requested_program.get("source_ids", []) == ["a", "b", "c"], "program handoff preserves saved source ids")
	panel.show_program_placeholder({"type": "dream_finale_program", "status": "ready", "source_ids": ["a", "b", "c"], "profile": {"valid": true, "route_rule": "long_charge", "anchor_rule": "relay", "climax_rule": "spotlight"}}, "boss_ready")
	_check(panel.visible and panel._message.contains("节目单已打开"), "program handoff opens a stable placeholder view")
	var confirm_button: Button = panel.get_node_or_null("ConfirmProgram") as Button
	_check(confirm_button != null and confirm_button.visible, "program placeholder keeps a visible confirmation button")
	_check(panel._message.contains("蓄力") and panel._message.contains("接力") and panel._message.contains("聚光灯"), "program rules use player-readable labels")
	var many_rows: Array[Dictionary] = []
	var many_probabilities := {}
	for index in range(9):
		var id := "candidate-%d" % index
		many_rows.append({"instance_id": id, "name": id, "hp_lost": index})
		many_probabilities[id] = 1.0 / 9.0
	panel.show_candidates(1, many_rows, many_probabilities)
	_check(panel.get_node_or_null("CandidateNext") != null and panel.get_node_or_null("CandidatePrev") != null, "多候选阶段提供分页控制")
	_check(panel.get_node_or_null("Abstain") != null and panel.get_node_or_null("Abstain").visible, "多候选阶段弃权按钮始终可见")
	var pages: int = panel.candidate_page_count()
	_check(pages == 3, "九个候选被拆成三个可操作页面")
	for page in range(pages):
		_check(panel.visible_candidate_ids().size() > 0, "候选分页 %d 至少有一项可见" % (page + 1))
		if page < pages - 1:
			panel.get_node_or_null("CandidateNext").emit_signal("pressed")
	_check(panel.visible_candidate_ids().has("candidate-8"), "最后一页候选可以到达并操作")
	panel.update_probabilities({"candidate-6": 0.77, "candidate-7": 0.11, "candidate-8": 0.12})
	for candidate_index in range(6, 9):
		var last_page_button: Button = panel.get_node_or_null("Nominate_candidate-%d" % candidate_index) as Button
		_check(last_page_button != null and last_page_button.text.contains("candidate-%d" % candidate_index), "末页刷新保留候选名称 %d" % candidate_index)
		_check(last_page_button != null and last_page_button.text.contains("受伤经历 %d" % candidate_index), "末页刷新保留候选受伤值 %d" % candidate_index)
		var expected_chance: String = {6: "77.0%", 7: "11.0%", 8: "12.0%"}[candidate_index]
		_check(last_page_button != null and last_page_button.text.contains(expected_chance), "末页刷新更新候选概率 %d" % candidate_index)
	panel.get_node_or_null("Nominate_candidate-8").emit_signal("pressed")
	_check(submitted_value == "candidate-8", "最后一页候选按钮可实际提交")
	await process_frame
	var awaiting_entry := {"type": "dream_finale_program", "status": "awaiting_dream_finale_profile", "source_ids": ["a", "b", "c"]}
	panel.show_program_placeholder(awaiting_entry, "explore")
	await process_frame
	var awaiting_open_button: Button = panel.get_node_or_null("OpenProgramList") as Button
	var awaiting_confirm_button: Button = panel.get_node_or_null("ConfirmProgram") as Button
	_check(awaiting_open_button != null and awaiting_open_button.visible, "恢复待配置节目单显示打开入口")
	_check(awaiting_confirm_button != null and not awaiting_confirm_button.visible, "恢复待配置节目单不显示终幕确认")
	panel.show_reveal_only(2, rows, {"stage": 2, "selected_id": "a"}, 0.0)
	var before_reveal_only := submitted_value
	panel.get_node_or_null("Nominate_a").emit_signal("pressed")
	_check(submitted_value == before_reveal_only, "saved reveal-only state cannot submit another nomination")
	panel.queue_free()
	await process_frame
	if failures.is_empty():
		print("DREAM_STAGE_PANEL: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("DREAM_STAGE_PANEL: " + failure)
		quit(1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
