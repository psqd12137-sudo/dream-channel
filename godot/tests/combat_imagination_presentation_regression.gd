extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	_check(packed != null, "channel_3d.tscn must load")
	if packed == null:
		_finish()
		return
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	var dof_before := {
		"blur": game.presentation_settings.depth_of_field_blur_strength,
		"focus": game.presentation_settings.depth_of_field_focus_width,
	}
	game.animation_duration_scale = 1.0
	game.start_combat_lab("hall")
	_check(game.active_animation_kind == "combat_entry", "imagination lab must use the existing combat entry animation")
	_check(game.battle_presentation_root != null and game.battle_presentation_root.scale.x > 0.0, "presentation root must have a valid entry scale")
	_check(game.battle_presentation_root != null and game.battle_presentation_root.has_meta("imagination_entry_stagger"), "imagination entry must expose profile-driven stagger metadata")
	await process_frame
	await process_frame
	var camera := game.camera as Camera3D
	var logical_before := _combat_snapshot(game.combat)
	_check(game.battle_imagination_mode == "imagination", "combat lab must start in imagination mode")
	_check(game.battle_imagination_profile.get("visual_scale", 0.0) > 0.0, "combat lab must expose an imagination profile")
	var profile: Dictionary = game.battle_imagination_profile
	_check(float(profile["visual_scale"]) >= 0.90 and float(profile["visual_scale"]) <= 1.20, "visual scale must stay inside the first-pass range")
	_check(float(profile["prop_scale"]) >= 1.0 and float(profile["prop_scale"]) <= 1.35, "prop scale must stay inside the first-pass range")
	_check(not str(profile["material_family"]).is_empty(), "profile must name a material family")
	_check(not str(profile["hero_prop_id"]).is_empty(), "profile must select a hero prop when room props exist")
	_check(game.battle_presentation_root != null, "combat lab must expose a presentation root")
	_check(game.combat_presentation_lab, "combat lab must expose the test-only A/B presentation state")
	_check(game.hud.combat_lab_ab_controls_visible(), "combat lab must expose A/B controls without enabling them in formal combat")
	_check(_count_meta(game.battle_presentation_root, "imagination_material") > 0, "imagination mode must tag toy materials")
	_check(_count_meta(game.battle_presentation_root, "imagination_hero_prop") == 1, "imagination mode must have one hero prop")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_focus_width, float(profile["dof_focus_width"])), "combat lab must use profile focus width")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_blur_strength, float(profile["dof_blur_strength"])), "combat lab must use profile blur strength")
	game.set_battle_imagination_mode("baseline")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_focus_width, float(dof_before["focus"])), "baseline must restore the user's focus width")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_blur_strength, float(dof_before["blur"])), "baseline must restore the user's blur strength")
	var baseline_span: float = game.battle_visual_world(Vector2i(0, 0)).distance_to(game.battle_visual_world(Vector2i(1, 0)))
	game.pan_battle_camera(Vector2(1200, -600))
	game.set_battle_imagination_mode("imagination")
	var imagination_span: float = game.battle_visual_world(Vector2i(0, 0)).distance_to(game.battle_visual_world(Vector2i(1, 0)))
	_check(imagination_span > baseline_span, "imagination mode must visibly expand the room")
	_check(_all_battle_visual_cells_in_viewport(game, camera), "switching imagination mode must refit every visual battle cell")
	_check(_combat_snapshot(game.combat) == logical_before, "visual A/B switching must preserve combat state")
	var cell := Vector2i(2, 1)
	var projected := camera.unproject_position(game.battle_visual_world(cell))
	_check(game.battle_cell_from_viewport(projected) == cell, "scaled presentation must preserve battle picking")
	game.orbit_battle_camera(Vector2(196, 0))
	var rotated_projected := camera.unproject_position(game.battle_visual_world(cell))
	_check(game.battle_cell_from_viewport(rotated_projected) == cell, "rotated scaled presentation must preserve battle picking")
	_check(_all_battle_visual_cells_in_viewport(game, camera), "rotated imagination mode must keep every visual battle cell in view")
	game.go_home()
	_check(is_equal_approx(game.presentation_settings.depth_of_field_focus_width, float(dof_before["focus"])), "direct lab exit must restore the user's focus width")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_blur_strength, float(dof_before["blur"])), "direct lab exit must restore the user's blur strength")
	_check(game.battle_lab_dof_restore.is_empty(), "direct lab exit must clear the saved DOF snapshot")
	game.queue_free()
	await process_frame
	_finish()


func _combat_snapshot(combat: RefCounted) -> Dictionary:
	var enemies: Array[Dictionary] = []
	var footprint = combat.get("footprint")
	if footprint == null:
		footprint = []
	for enemy_id in combat.enemy_order:
		var enemy = combat.enemy_by_id(enemy_id)
		enemies.append({"id": str(enemy_id), "pos": enemy.pos, "alive": enemy.alive(), "revealed": enemy.revealed})
	return {
		"player_pos": combat.player_pos,
		"enemy_order": combat.enemy_order.duplicate(),
		"enemies": enemies,
		"energy": combat.energy,
		"walls": combat.walls.duplicate(true),
		"footprint": footprint.duplicate(true),
	}


func _all_battle_visual_cells_in_viewport(game: Node3D, camera: Camera3D) -> bool:
	var view_size: Vector2 = game.world_view_rect.size
	for y in range(game.combat.rows):
		for x in range(game.combat.cols):
			var screen_position := camera.unproject_position(game.battle_visual_world(Vector2i(x, y)))
			if screen_position.x < 0.0 or screen_position.y < 0.0 or screen_position.x > view_size.x or screen_position.y > view_size.y:
				return false
	return true


func _count_meta(root_node: Node, meta_key: String) -> int:
	if root_node == null:
		return 0
	var count := 1 if root_node.has_meta(meta_key) else 0
	for child: Node in root_node.get_children():
		count += _count_meta(child, meta_key)
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("COMBAT_IMAGINATION_PRESENTATION: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_IMAGINATION_PRESENTATION: %s" % failure)
		quit(1)
