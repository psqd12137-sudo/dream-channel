extends SceneTree

var failures: Array[String] = []
var submitted_value := "unset"
var revealed_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var panel = load("res://scripts/dream_stage_panel.gd").new()
	root.add_child(panel)
	panel.size = Vector2(1280, 800)
	panel.submitted.connect(func(id: String) -> void: submitted_value = id)
	panel.reveal_finished.connect(func() -> void: revealed_count += 1)
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
	panel.reveal({"stage": 3, "selected_id": "b"}, 0.0)
	_check(panel._message.contains("节目单入口"), "stage three recap exposes the program entry")
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
