extends SceneTree

var failures: Array[String] = []
var game: Node3D
var capture := "--capture" in OS.get_cmdline_user_args()


func _init() -> void:
	call_deferred("run")


func run() -> void:
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 1.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://toyhouse_sequence_test.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	await process_frame
	game.toggle_home_tests()
	game.start_toyhouse_sequence_lab()
	var target: Vector2i = game.toyhouse_sequence_target
	var room_nodes: Array[Node3D] = game._find_room_instance_nodes(target)
	var room_node: Node3D = room_nodes[0] if not room_nodes.is_empty() else null
	_check(game.animation_busy and game.active_animation_kind == "room_drop", "toyhouse sequence starts with the room drop")
	_check(room_node != null, "toyhouse sequence exposes the new room visual root")
	if room_node != null:
		_check(game.active_room_assembly != null, "toyhouse sequence uses the shared cartoon assembly")
		_check(int(room_node.get_meta("assembly_part_count", 0)) > 0, "toyhouse sequence stages visible room parts")
	_check(not bool(game.room_rules.placed[target].get("revealed", true)), "toyhouse sequence keeps the new room covered during assembly")
	if capture:
		await _capture_frame("drop")
	await process_frame
	await process_frame
	_check(game.phase == "lab_toyhouse_sequence", "toyhouse sequence opens from the test area")
	_check(game.toyhouse_sequence_active, "toyhouse sequence marks the visual sandbox active")
	_check(game.room_rules.instance_count() == 2, "toyhouse sequence prepares exactly two adjacent rooms")
	var observed_steps := await _wait_for_effect(game, 6.0)
	_check(bool(observed_steps.get("assembly_hold", false)), "toyhouse sequence includes a visible assembly hold")
	_check(bool(observed_steps.get("jump", false)), "toyhouse sequence hands off to the actor jump")
	_check(not game.animation_busy, "toyhouse sequence finishes all visual effects")
	_check(game.phase == "lab_toyhouse_sequence" and game.toyhouse_sequence_step == "ready", "toyhouse sequence returns to its replayable ready state")
	_check(game.current_room_pos == target, "toyhouse sequence moves the actor into the new room")
	_check(bool(game.room_rules.placed[target].get("revealed", false)) and bool(game.room_rules.placed[target].get("visited", false)), "toyhouse sequence reveals and visits the new room once")
	var token := game.house_root.get_node_or_null("LiliToken") as Node3D
	var slots: Array[Dictionary] = game.room_interaction_slots(target)
	var expected: Vector3 = game._house_world(target)
	if token != null and not slots.is_empty():
		expected = game._interaction_slot_house_position(slots[0], "position")
	_check(token != null and token.position.distance_to(expected) < 0.02, "toyhouse sequence settles the actor on the destination slot")
	if capture and root.get_texture() != null:
		_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../output/toyhouse-sequence-ready.png")) == OK, "toyhouse sequence ready capture saves")
	game.replay_toyhouse_sequence_lab()
	await process_frame
	await process_frame
	_check(game.phase == "lab_toyhouse_sequence" and game.animation_busy, "toyhouse sequence can replay from its ready state")
	await _wait_for_effect(game, 6.0)
	_check(game.toyhouse_sequence_step == "ready" and not game.animation_busy, "toyhouse sequence replay reaches the same ready state")
	game.go_home()
	await process_frame
	_check(game.phase == "home", "toyhouse sequence exits to the title")
	_check(not game.run_save_repository.exists(), "toyhouse sequence leaves the formal save untouched")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("TOYHOUSE_SEQUENCE: PASS entry-drop-pause-jump-reveal-replay-save-isolation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("TOYHOUSE_SEQUENCE: " + failure)
		quit(1)


func _wait_for_effect(target_game: Node, timeout_seconds: float) -> Dictionary:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var observed := {"assembly_hold": false, "jump": false}
	while target_game.animation_busy and Time.get_ticks_msec() < deadline:
		if target_game.toyhouse_sequence_step == "assembly_hold":
			observed["assembly_hold"] = true
		elif target_game.toyhouse_sequence_step == "jump":
			observed["jump"] = true
		await process_frame
	_check(not target_game.animation_busy, "toyhouse sequence effect completes before timeout")
	return observed


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _capture_frame(label: String) -> void:
	if root.get_texture() == null:
		return
	await RenderingServer.frame_post_draw
	var capture_path := ProjectSettings.globalize_path("res://../output/toyhouse-sequence-%s.png" % label)
	_check(root.get_texture().get_image().save_png(capture_path) == OK, "toyhouse sequence %s capture saves" % label)
