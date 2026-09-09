extends SceneTree

var failures: Array[String] = []
var game: Node3D

func _init() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://wall_cutaway_transition_test.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var target: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(target)
	game.place_selected_offer()
	await process_frame
	var composer := game.house_root.get_node_or_null("KenneyFormalComposer") as Node3D
	_check(composer != null, "formal composer exists")
	if composer == null:
		_finish()
		return
	game.set_process(false)
	_check(composer.has_method("set_cutaway_transition_mode"), "composer exposes cutaway transition mode")
	_check(composer.has_method("cutaway_transition_state"), "composer exposes transition state for comparison")
	if not composer.has_method("set_cutaway_transition_mode"):
		_finish()
		return
	var baseline := _edge_visibility(composer)
	composer.set_cutaway_transition_mode(1)
	composer.apply_camera_cutaway(Vector2i.ZERO, Vector2(0, 1))
	await create_timer(0.45).timeout
	var retract_state: Dictionary = composer.cutaway_transition_state()
	_check(int(retract_state.get("mode", -1)) == 1 and int(retract_state.get("active", 0)) == 0, "retract transition settles")
	var retract_result := _edge_visibility(composer)
	composer.set_cutaway_transition_mode(2)
	composer.apply_camera_cutaway(Vector2i.ZERO, Vector2(1, 0))
	await create_timer(0.45).timeout
	var wave_state: Dictionary = composer.cutaway_transition_state()
	_check(int(wave_state.get("mode", -1)) == 2 and int(wave_state.get("active", 0)) == 0, "wave transition settles")
	_check(_edge_visibility(composer) == _edge_visibility_after_direction(composer, Vector2(1, 0)), "wave result matches the cutaway decision")
	composer.set_cutaway_transition_mode(0)
	composer.apply_camera_cutaway(Vector2i.ZERO, Vector2(0, 1))
	await process_frame
	_check(_edge_visibility(composer) == baseline or retract_result != baseline, "instant mode remains available and updates visibility")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	_finish()

func _edge_visibility(composer: Node3D) -> Dictionary:
	var result := {}
	for raw_key: Variant in composer.structural_edge_nodes.keys():
		var key := str(raw_key)
		var node := composer.structural_edge_nodes[key] as Node3D
		result[key] = node != null and node.visible
	return result

func _edge_visibility_after_direction(composer: Node3D, direction: Vector2) -> Dictionary:
	var copy: Array = composer.cutaway_culled_edge_keys.duplicate()
	composer.apply_camera_cutaway(Vector2i.ZERO, direction)
	var result := _edge_visibility(composer)
	composer.cutaway_culled_edge_keys = copy
	return result

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("WALL_CUTAWAY_TRANSITION: PASS modes=instant-retract-wave final-visibility")
		quit(0)
	else:
		for failure in failures:
			push_error("WALL_CUTAWAY_TRANSITION: " + failure)
		quit(1)
