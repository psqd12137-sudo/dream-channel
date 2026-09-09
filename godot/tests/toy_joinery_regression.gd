extends SceneTree
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_tactile_lab()
	var lab = game.tactile_lab
	lab.set_reference_mode()
	if not lab.has_method("toggle_refined_structure"):
		push_error("JOINERY: missing refined structure comparison")
		game.go_home()
		game.queue_free()
		await process_frame
		quit(1)
		return
	if not lab.has_method("toggle_reference_feature"):
		push_error("JOINERY: missing independent toy interface controls")
		game.go_home()
		game.queue_free()
		await process_frame
		quit(1)
		return
	if lab.joinery == null:
		push_error("JOINERY: failed to initialise geometry")
		quit(1)
		return
	var layout: Dictionary = game.room_rules.placed.duplicate(true)
	var camera_pose: Transform3D = game.camera.transform
	check(game.presentation_settings.depth_of_field_enabled, "original tilt shift is enabled in C")
	check(is_equal_approx(game.presentation_settings.depth_of_field_blur_strength, 5.5) and is_equal_approx(game.presentation_settings.depth_of_field_focus_width, 0.18), "C restores original tilt shift parameters")
	for record in lab.joinery.refined_hidden:
		check(not record.node.visible, "refined shell hides extra floor and edge layers")
	for record in lab.joinery.base_records:
		check(is_equal_approx(record.refined.get_aabb().size.y, record.original.get_aabb().size.y * 0.75), "refined shell is 25 percent thinner")
	lab.toggle_refined_structure()
	check(not lab.refined_structure and game.camera.transform == camera_pose, "old C uses same camera")
	for record in lab.joinery.base_records:
		check(record.node.mesh == record.toy, "old C restores previous geometry")
	lab.toggle_refined_structure()
	lab.toggle_reference_feature(3)
	check(not game.presentation_settings.depth_of_field_enabled and lab.joinery.enabled, "DOF toggles independently")
	lab.toggle_reference_feature(3)
	var mat = lab.reference_root.get_node("CuttingMat")
	var mat_top: float = (mat.global_transform * mat.get_aabb()).end.y
	for record in lab.joinery.base_records:
		check(absf((record.node.global_transform * record.node.get_aabb()).position.y - mat_top) < 0.001, "base must contact cutting mat")
		check(record.node.mesh.get_faces().size() > 36, "base silhouette has physical contours")
	check(lab.joinery.interfaces.any(func(r): return r.connected), "sample includes paired door")
	check(lab.joinery.interfaces.any(func(r): return not r.connected), "sample includes open socket")
	for node in game.house_root.find_children("Frontier_*", "Node3D", false, false):
		check(not node.visible, "no detached frontier markers")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(1130, 302) * game.hud.ui_scale + game.hud.ui_offset
	game.hud._gui_input(click)
	check(not lab.joinery.enabled, "HUD toggles physical base")
	check(lab.reference_features[1] and lab.reference_features[2], "physical switch preserves other choices")
	game.hud._gui_input(click)
	check(lab.joinery.enabled, "HUD restores physical base")
	var env = game.world_root.get_node("WorldEnvironment").environment
	lab.toggle_reference_feature(2)
	check(game.world_root.get_node("WorldEnvironment").environment != env, "atmosphere restores baseline lighting")
	lab.toggle_reference_feature(2)
	check(game.camera.transform == camera_pose and game.room_rules.placed == layout, "reference switches preserve camera and rules")
	var assembly = load("res://scripts/toy_room_assembly.gd").new()
	assembly.toy_snap_enabled = true
	var base: MeshInstance3D = lab.joinery.base_records[0].node
	var original_pose := base.transform
	var bottom_before: float = (base.global_transform * base.get_aabb()).position.y
	assembly.pose_piece({"node": base, "pose": original_pose, "landing": 0.53, "kind": "base"}, 0.58)
	check(absf((base.global_transform * base.get_aabb()).position.y - bottom_before) < 0.001, "compression keeps underside planted")
	base.transform = original_pose
	lab.replay()
	check(game.active_room_assembly.toy_snap_enabled, "reference replay enables shared snap")
	lab.toggle_reference_feature(1)
	check(not game.active_room_assembly.toy_snap_enabled, "mid-animation switch restarts without snap")
	lab.set_mode(false)
	check(not lab.joinery.enabled, "A removes experimental base")
	for record in lab.joinery.base_records:
		check(record.node.mesh == record.original, "A restores source mesh")
	lab.set_reference_mode()
	game.go_home()
	check(game.tactile_lab == null and game.active_room_assembly == null, "exit cancels replay")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("JOINERY: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
