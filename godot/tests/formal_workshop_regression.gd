extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	var profile_script = load("res://scripts/formal_workshop_profile.gd")
	var profile: Dictionary = profile_script.for_room("reference_workshop_demo")
	check(not profile.has("error"), "demo room must have a formal profile")
	check(profile.room_presentation.center_base == "ToyWorkbench", "profile must name the center room base")
	check(profile.room_presentation.center_base_size.size() == 3, "profile must fix the center base dimensions")
	check(profile.room_presentation.cutting_mat_size.size() == 3, "profile must fix the cutting mat dimensions")
	check(profile.material_families.size() >= 8, "profile must cover the material families")
	check(profile.camera.dof_default == "off_or_weak", "profile must keep DOF weak by default")
	check(profile.logic_guards.decor_group == "workshop_decor", "profile must reserve a decor group")

	var game = load("res://channel_3d.tscn").instantiate()
	var path := "user://formal_workshop_regression_save.json"
	var repository = load("res://scripts/run_save_repository.gd").new(path, game.EXE_SOURCE_ID)
	game.run_save_repository = repository
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	game.start_new_run(false, 2026091001)
	game.choose_omen(0)
	var before: Dictionary = repository.read().duplicate(true)
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var environment_before = game.world_root.get_node("WorldEnvironment").environment
	var key_before = game.world_root.get_node("KeyLight")
	var fill_before = game.world_root.get_node("FillLight")
	var key_snapshot := {"color": key_before.light_color, "energy": key_before.light_energy, "angular": key_before.light_angular_distance}
	var fill_snapshot := {"color": fill_before.light_color, "energy": fill_before.light_energy, "angular": fill_before.light_angular_distance}
	var camera_transform_before: Transform3D = game.camera.transform
	var camera_size_before: float = game.camera.size
	var token_transform_before: Transform3D = game.house_root.get_node("LiliToken").transform
	var settings = game.presentation_settings
	var dof_before := [settings.depth_of_field_enabled, settings.depth_of_field_blur_strength, settings.depth_of_field_focus_width]
	check(game.start_formal_workshop_preview(), "formal preview entry must start from the isolated lab")
	await process_frame
	var lab = game.tactile_lab
	check(lab != null and game.phase == "lab_tactile", "formal preview remains in the isolated lab phase")
	check(lab.reference_root != null and lab.reference_root.is_in_group(&"workshop_decor"), "reference root must be workshop decor")
	check(lab.reference_root.find_child("CuttingMat", true, false) != null, "formal room must have the green cutting mat")
	check(lab.reference_root.find_child("BookStack", true, false) != null, "formal room must have books")
	check(lab.reference_root.find_child("PartsTray", true, false) != null, "formal room must have a parts tray")
	check(lab.reference_root.find_child("WorkshopBack", true, false) != null, "formal room must have the rear environment")
	check(not settings.depth_of_field_enabled, "formal baseline must keep DOF off")
	check(lab.reference_root.get_tree().get_nodes_in_group(&"workshop_decor").size() >= 10, "formal room must expose peripheral decor")
	for node: Node in lab.reference_root.get_tree().get_nodes_in_group(&"workshop_decor"):
		check(not node.is_in_group(&"room_prop"), "workshop decor must stay out of room_prop logic")
	for node: Node in game.house_root.find_children("ToyWorkbench*", "MeshInstance3D", true, false):
		check(bool(node.get_meta("formal_room_base", false)), "center room base must be marked as the formal base")
	var layout_before: Dictionary = game.room_rules.placed.duplicate(true)
	var workshop_state: Dictionary = game.formal_workshop_preview_snapshot()
	check(workshop_state.room_id == "reference_workshop_demo" and workshop_state.state == "workshop", "workshop preview must expose a stable room id")
	var dream_state: Dictionary = game.enter_formal_tv_dream_preview()
	check(dream_state.ok and dream_state.room_id == workshop_state.room_id and dream_state.state == "tv_dream", "TV dream must reuse the room id")
	check(dream_state.outline == workshop_state.outline, "TV dream must retain the main furniture outline")
	var returned: Dictionary = game.return_formal_workshop_preview()
	check(returned.ok and returned.state == "workshop", "preview must return to workshop state")
	check(game.room_rules.placed == layout_before, "preview must preserve room logic grid")
	game.go_home()
	await process_frame
	check(repository.read() == before, "formal preview must not change the isolated save data")
	check(FileAccess.get_file_as_bytes(path) == before_bytes, "formal preview must not rewrite the save")
	check(game.world_root.get_node("WorldEnvironment").environment == environment_before, "exit must restore the source environment")
	check(key_before.light_color == key_snapshot.color and is_equal_approx(key_before.light_energy, key_snapshot.energy) and is_equal_approx(key_before.light_angular_distance, key_snapshot.angular), "exit must restore key light")
	check(fill_before.light_color == fill_snapshot.color and is_equal_approx(fill_before.light_energy, fill_snapshot.energy) and is_equal_approx(fill_before.light_angular_distance, fill_snapshot.angular), "exit must restore fill light")
	check(game.camera.transform == camera_transform_before and is_equal_approx(game.camera.size, camera_size_before), "exit must restore camera")
	check(game.house_root.get_node("LiliToken").transform == token_transform_before, "exit must restore character transform")
	check(settings.depth_of_field_enabled == dof_before[0] and is_equal_approx(settings.depth_of_field_blur_strength, dof_before[1]) and is_equal_approx(settings.depth_of_field_focus_width, dof_before[2]), "exit must restore DOF")
	repository.clear()
	game.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("FORMAL_WORKSHOP: " + failure)
	print("FORMAL_WORKSHOP: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
