extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	if not game.has_method("start_tactile_lab"):
		push_error("TACTILE: missing in-game comparison entry")
		quit(1)
		return
	var repository = load("res://scripts/run_save_repository.gd").new("user://tactile_regression_save.json", game.EXE_SOURCE_ID)
	game.run_save_repository = repository
	game.animation_duration_scale = 0.0
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var saved: Dictionary = repository.read().duplicate(true)
	game.go_home()
	var settings = game.presentation_settings
	var dof: bool = settings.depth_of_field_enabled
	var strength: float = settings.depth_of_field_blur_strength
	var world_env = game.world_root.get_node("WorldEnvironment").environment
	var original_ambient: float = world_env.ambient_light_energy
	var config_before := FileAccess.get_file_as_bytes(settings.DISPLAY_SETTINGS_PATH)
	game.animation_duration_scale = 1.0
	game.home_tests_open = true
	game._refresh_hud()
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.hud.HOME_TEST_TACTILE_RECT.get_center() * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	await process_frame
	var lab = game.tactile_lab
	if not lab.has_method("set_reference_mode"):
		push_error("TACTILE: missing reference workshop preset")
		quit(1)
		return
	check(lab != null and game.phase == "lab_tactile", "entry must stay in test phase")
	check(game.run_save_repository != repository, "lab must isolate save repository")
	var layout: Dictionary = game.room_rules.placed.duplicate(true)
	var camera_pose: Transform3D = game.camera.transform
	var camera_size: float = game.camera.size
	lab.set_mode(false)
	check(game.world_root.get_node("WorldEnvironment").environment == lab.baseline_environment, "A restores baseline environment")
	for record: Dictionary in lab.material_records:
		check(record.node.material_override == record.original_override, "A must restore original material")
		check(record.node.mesh == record.original_mesh, "A must restore original geometry")
		for i in range(record.original_surfaces.size()):
			check(record.node.get_surface_override_material(i) == record.original_surfaces[i], "A restores each surface override")
	lab.set_mode(true)
	click.position = Vector2(1130, 200) * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	check(not lab.mode_b, "A button is wired through real HUD")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_B
	game.hud._input(key)
	check(lab.mode_b, "B shortcut is wired through real HUD")
	check(game.camera.transform == camera_pose and game.camera.size == camera_size, "A/B must preserve camera")
	check(game.room_rules.placed == layout, "A/B must preserve layout")
	game.animation_duration_scale = 1.0
	await create_timer(0.8).timeout
	check(game.camera.transform == camera_pose and game.camera.size == camera_size, "intro tween must not drift comparison camera")
	game.orbit_house_camera(Vector2(100, 0))
	check(game.camera.transform != camera_pose, "lab allows real orbit input")
	game.zoom_house_camera(Vector2.ZERO, 0.9)
	check(game.camera.size != camera_size, "lab allows zoom input")
	lab.reset_camera()
	check(game.camera.transform == camera_pose and game.camera.size == camera_size, "reset restores common camera")
	check(not lab.features[3], "band blur must remain opt-in")
	key.keycode = KEY_C
	game.hud._input(key)
	check(lab.reference_mode and lab.reference_root.visible, "reference workshop is visible")
	var composer = game.house_root.get_node_or_null("KenneyFormalComposer")
	check(composer != null, "C must keep the formal wall composer")
	if composer != null:
		var non_focus_wall_visibility := _non_focus_outer_wall_visibility(composer)
		game.orbit_house_camera(Vector2(-PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0.0))
		await create_timer(0.35).timeout
		check(_non_focus_outer_wall_visibility(composer) == non_focus_wall_visibility, "rotating C must not recompose non-focused room walls")
		lab.reset_camera()
		var initial_culled_edges: Array[String] = composer.cutaway_culled_edge_keys.duplicate()
		initial_culled_edges.sort()
		check(_culled_outer_axis_count(composer) <= 1, "C must cut away one near wall side at a time")
		for _quarter in range(4):
			game.orbit_house_camera(Vector2(-PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0.0))
			await create_timer(0.35).timeout
		var final_culled_edges: Array[String] = composer.cutaway_culled_edge_keys.duplicate()
		final_culled_edges.sort()
		check(final_culled_edges == initial_culled_edges, "a full camera turn must restore the same wall layout")
		lab.reset_camera()
	if not lab.has_method("set_material_detail"):
		push_error("TACTILE: missing asset material detail preset")
		quit(1)
		return
	check(lab.material_detail_records.size() > 20, "C captures per-asset material records")
	var material_kinds := {}
	for record: Dictionary in lab.material_detail_records:
		material_kinds[record.kind] = true
	check(material_kinds.has("plastic") and material_kinds.has("painted_wood") and material_kinds.has("felt"), "C separates plastic, wood and fabric")
	lab.set_material_detail(false)
	check(not lab.material_detail_enabled, "material detail can be disabled for comparison")
	lab.set_material_detail(true)
	check(lab.material_detail_enabled, "material detail can be restored")
	check(game.camera.transform == camera_pose and game.camera.size == camera_size, "reference keeps comparison camera")
	check(not lab.features[1], "reference retains original room materials")
	for name in ["CuttingMat", "BookStack", "TapeRoll", "PartsTray", "WorkshopWindow", "ShelfLeft", "DeskLamp"]:
		check(lab.reference_root.find_child(name, true, false) != null, "reference includes " + name)
	lab.set_mode(false)
	check(not lab.reference_root.visible, "A hides reference room and its lamps")
	for record in lab.reference_bases:
		check(record.node.visible == record.visible, "A restores original base visibility")
	click.position = Vector2(1130, 595) * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	check(lab.reference_mode, "C button is wired through real HUD")
	lab.set_mode(true)
	check(lab.decor_root.visible, "B shows tabletop")
	lab.toggle_feature(0)
	check(not lab.decor_root.visible, "tabletop has independent switch")
	lab.toggle_feature(1)
	check(lab.features[2] and not lab.features[1], "material toggle preserves lighting choice")
	lab.toggle_feature(2)
	check(game.world_root.get_node("WorldEnvironment").environment == lab.baseline_environment, "lighting toggle restores baseline")
	lab.set_mode(true)
	game.animation_duration_scale = 0.05
	lab.replay()
	check(game.active_room_assembly != null, "replay uses shared cartoon assembly")
	var deadline := Time.get_ticks_msec() + 5000
	while game.animation_busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.animation_busy and game.phase == "lab_tactile", "replay must finish in lab")
	check(game.current_room_pos == lab.target, "actor must enter sample room")
	game.animation_duration_scale = 1.0
	lab.replay()
	lab.set_mode(false)
	check(game.active_room_assembly != null, "switching during replay restarts assembly")
	lab.set_reference_mode()
	game.go_home()
	check(game.tactile_lab == null and game.active_room_assembly == null, "exit cleans active animation")
	check(game.run_save_repository == repository and repository.read() == saved, "formal save remains byte-equivalent data")
	check(game.world_root.get_node("WorldEnvironment").environment == world_env, "environment resource restored")
	check(world_env.ambient_light_energy == original_ambient, "source environment was not mutated")
	check(FileAccess.get_file_as_bytes(settings.DISPLAY_SETTINGS_PATH) == config_before, "experimental settings never persisted")
	check(settings.depth_of_field_enabled == dof and settings.depth_of_field_blur_strength == strength, "DOF restored")
	game.start_tactile_lab()
	game.go_home()
	check(game.run_save_repository == repository, "repeat entry restores repository")
	repository.clear()
	game.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("TACTILE: " + failure)
	print("TACTILE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _non_focus_outer_wall_visibility(composer: Node) -> Dictionary:
	var result := {}
	for raw_key: Variant in composer.visual_edge_records.keys():
		var edge_key := str(raw_key)
		var record: Dictionary = composer.visual_edge_records[edge_key]
		if str(record.get("kind", "")) != "outer":
			continue
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		if int(composer.occupancy.get(cell, -1)) == composer.cutaway_focus_room_index:
			continue
		var node: Node3D = composer.structural_edge_nodes.get(edge_key)
		if node != null:
			result[edge_key] = node.visible
	return result

func _culled_outer_axis_count(composer: Node) -> int:
	var axes := {}
	for edge_key in composer.cutaway_culled_edge_keys:
		var record: Dictionary = composer.visual_edge_records.get(edge_key, {})
		if str(record.get("kind", "")) != "outer" or bool(record.get("passage_open", false)):
			continue
		var cell: Vector2i = record.get("cell", Vector2i.ZERO)
		var neighbor: Vector2i = record.get("neighbor", Vector2i.ZERO)
		var direction := neighbor - cell
		axes[direction] = true
	return axes.size()
