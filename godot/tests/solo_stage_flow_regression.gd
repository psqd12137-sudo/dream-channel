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
	var invalid = load("res://scripts/solo_stage_flow.gd").new()
	_check(not invalid.restore({"version": 99}), "unknown version is rejected")
	_check(not invalid.restore({"version": 1, "stage": 2, "results": [], "pending_result": {"stage": 1}}), "inconsistent pending result is rejected")
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
