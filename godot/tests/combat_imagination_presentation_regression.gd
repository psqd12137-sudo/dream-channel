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
	await create_timer(0.40).timeout
	var entry_hero := _imagination_hero(game.battle_presentation_root)
	var entry_baseline_scale := entry_hero.get_meta("imagination_base_scale", Vector3.ONE) as Vector3 if entry_hero != null else Vector3.ZERO
	_check(game.battle_presentation_root != null and bool(game.battle_presentation_root.get_meta("imagination_entry_active", false)), "entry regression must switch modes while the imagination stagger is active")
	game.set_battle_imagination_mode("imagination")
	var entry_idle_tween: Tween = entry_hero.get_meta("imagination_idle_tween") as Tween if entry_hero != null and entry_hero.has_meta("imagination_idle_tween") else null
	await create_timer(0.90).timeout
	game.set_battle_imagination_mode("baseline")
	await _wait_for_animation(game, 2.0)
	_check(entry_hero != null and entry_hero.scale.is_equal_approx(entry_baseline_scale), "baseline during entry must restore the hero's baseline scale")
	_check(entry_hero != null and not entry_hero.has_meta("imagination_hero_prop") and not entry_hero.has_meta("imagination_idle_tween"), "baseline during entry must clear imagination hero metadata and tween")
	_check(entry_idle_tween == null or not entry_idle_tween.is_running(), "baseline after repeated imagination entry selection must stop the first hero idle tween")
	game.set_battle_imagination_mode("imagination")
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
	var first_imagination_color := _first_imagination_material_color(game.battle_presentation_root)
	game.set_battle_imagination_mode("imagination")
	var repeated_imagination_color := _first_imagination_material_color(game.battle_presentation_root)
	_check(first_imagination_color.is_equal_approx(repeated_imagination_color), "repeated imagination selection must not accumulate material tint")
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
	var player := game.battle_actor_root.get_node_or_null("Player") as Node3D
	var player_baseline_scale := player.scale if player != null else Vector3.ZERO
	game.set_battle_imagination_mode("imagination")
	for _selection in range(8):
		game.select_or_play_card(0)
		game.cancel_selected_card()
		await create_timer(0.05).timeout
	await create_timer(0.40).timeout
	_check(player != null and player.scale.is_equal_approx(player_baseline_scale), "rapid public card selection must restore the player scale before baseline")
	game.set_battle_imagination_mode("baseline")
	await create_timer(0.30).timeout
	_check(player != null and player.scale.is_equal_approx(player_baseline_scale), "baseline must clear rapid public card selection feedback")
	game.go_home()
	_check(is_equal_approx(game.presentation_settings.depth_of_field_focus_width, float(dof_before["focus"])), "direct lab exit must restore the user's focus width")
	_check(is_equal_approx(game.presentation_settings.depth_of_field_blur_strength, float(dof_before["blur"])), "direct lab exit must restore the user's blur strength")
	_check(game.battle_lab_dof_restore.is_empty(), "direct lab exit must clear the saved DOF snapshot")
	game.queue_free()
	await process_frame
	await _assert_direct_exit_stops_entry_idle()
	await _assert_natural_entry_starts_idle_motion()
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


func _assert_direct_exit_stops_entry_idle() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.animation_duration_scale = 1.0
	game.start_combat_lab("hall")
	await create_timer(0.40).timeout
	var hero := _imagination_hero(game.battle_presentation_root)
	var baseline_scale := hero.get_meta("imagination_base_scale", Vector3.ONE) as Vector3 if hero != null else Vector3.ZERO
	game.set_battle_imagination_mode("imagination")
	var first_idle: Tween = hero.get_meta("imagination_idle_tween") as Tween if hero != null and hero.has_meta("imagination_idle_tween") else null
	await create_timer(0.90).timeout
	game.go_home()
	await create_timer(0.30).timeout
	_check(first_idle == null or not first_idle.is_running(), "direct exit after repeated imagination entry selection must stop the first hero idle tween")
	_check(hero != null and hero.scale.is_equal_approx(baseline_scale), "direct exit after repeated imagination entry selection must restore the hero scale")
	game.queue_free()
	await process_frame


func _assert_natural_entry_starts_idle_motion() -> void:
	var packed := load("res://channel_3d.tscn") as PackedScene
	var game := packed.instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.animation_duration_scale = 1.0
	game.start_combat_lab("hall")
	await _wait_for_natural_imagination_entry(game, 3.0)
	var hero := _imagination_hero(game.battle_presentation_root)
	var idle_tween: Tween = hero.get_meta("imagination_idle_tween") as Tween if hero != null and hero.has_meta("imagination_idle_tween") else null
	var position_before := hero.position if hero != null else Vector3.ZERO
	await create_timer(0.30).timeout
	_check(idle_tween != null and idle_tween.is_running(), "natural imagination entry must start the hero idle tween after stagger ownership releases")
	_check(hero != null and not is_equal_approx(hero.position.y, position_before.y), "hero must move after natural imagination entry settles")
	game.go_home()
	game.queue_free()
	await process_frame


func _wait_for_natural_imagination_entry(game: Node3D, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while (game.animation_busy or (game.battle_presentation_root != null and bool(game.battle_presentation_root.get_meta("imagination_entry_active", false)))) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not game.animation_busy and (game.battle_presentation_root == null or not bool(game.battle_presentation_root.get_meta("imagination_entry_active", false))), "natural imagination entry must settle before idle motion is sampled")


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


func _imagination_hero(root_node: Node) -> Node3D:
	if root_node == null:
		return null
	if root_node is Node3D and root_node.has_meta("imagination_hero_prop"):
		return root_node as Node3D
	for child: Node in root_node.get_children():
		var hero := _imagination_hero(child)
		if hero != null:
			return hero
	return null


func _first_imagination_material_color(root_node: Node) -> Color:
	if root_node == null:
		return Color.TRANSPARENT
	if root_node is MeshInstance3D and root_node.has_meta("imagination_material_restore"):
		var mesh_instance := root_node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
				if material != null:
					return material.albedo_color
	for child: Node in root_node.get_children():
		var color := _first_imagination_material_color(child)
		if color != Color.TRANSPARENT:
			return color
	return Color.TRANSPARENT


func _wait_for_animation(game: Node3D, timeout_seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while game.animation_busy and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not game.animation_busy, "combat entry must settle after a presentation mode switch")


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
