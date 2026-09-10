extends RefCounted

# Experimental presentation only. Room rules and assembly remain owned by the host.
const FORMAL_ROOM_ID := "reference_workshop_demo"
const FormalWorkshopProfile = preload("res://scripts/formal_workshop_profile.gd")
var host
var features: Array[bool] = [true, true, true, false]
var mode_b := true
var reference_mode := false
var reference_root: Node3D
var reference_environment: Environment
var reference_builder: RefCounted
var reference_bases: Array[Dictionary] = []
var reference_features: Array[bool] = [true, true, true, true, true]
var refined_structure := true
var joinery: RefCounted
var atmosphere_environment: Environment
var material_records: Array[Dictionary] = []
var material_detail_records: Array[Dictionary] = []
var reference_material_detail_records: Array[Dictionary] = []
var material_detail_enabled := false
var material_detail_shader: Shader = preload("res://shaders/asset_material_detail.gdshader")
var material_white_texture: Texture2D
var decor_root: Node3D
var target := Vector2i.ZERO
var entry := Vector2i.ZERO
var token_pose := Transform3D.IDENTITY
var saved_repository
var saved_environment: Environment
var baseline_environment: Environment
var sample_environment: Environment
var saved_lights: Array[Dictionary] = []
var baseline_lights: Array[Dictionary] = []
var saved_dof: Array = []
var saved_camera_transform := Transform3D.IDENTITY
var saved_camera_size := 0.0
var saved_token_transform := Transform3D.IDENTITY
var saved_house_camera: Dictionary = {}
var camera_defaults: Dictionary = {}
var generation := 0
var playing := false
var closed := false
var formal_preview_room_id := ""
var formal_preview_state := "workshop"

func _init(game) -> void:
	host = game

func start() -> void:
	saved_repository = host.run_save_repository
	saved_environment = host.world_root.get_node("WorldEnvironment").environment
	saved_camera_transform = host.camera.transform
	saved_camera_size = host.camera.size
	saved_token_transform = host.house_root.get_node("LiliToken").transform
	for property in ["house_camera_target", "house_camera_fit_size", "house_camera_zoom_ratio", "house_camera_user_adjusted", "house_camera_closeup", "house_camera_distance", "house_camera_yaw", "house_camera_pitch", "house_camera_following", "house_camera_user_hold", "house_camera_return_delay", "house_camera_returning", "house_camera_intro_weight", "house_camera_size_current", "house_camera_size_target"]:
		saved_house_camera[property] = host.get(property)
	host.world_root.get_node("WorldEnvironment").environment = saved_environment.duplicate()
	saved_lights = _light_snapshot()
	var settings = host.presentation_settings
	saved_dof = [settings.depth_of_field_enabled, settings.depth_of_field_blur_strength, settings.depth_of_field_focus_width]
	host.lab_controller.start_wall_transition_lab()
	if host.phase != "lab_wall_transition":
		close()
		return
	host.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://tactile_lab_isolated.json", host.EXE_SOURCE_ID)
	host.tactile_lab = self
	host.phase = "lab_tactile"
	target = host.current_room_pos
	var old_current: Vector2i = host.current_room_pos
	host.current_room_pos = Vector2i.ZERO
	var path: Array[Vector2i] = host.house_path_to(target)
	entry = path[path.size() - 2] if path.size() >= 2 else Vector2i.ZERO
	host.current_room_pos = old_current
	var composer = host.house_root.get_node("KenneyFormalComposer")
	composer.set_cutaway_transition_mode(1)
	host.house_camera_following = false
	host.house_camera_user_hold = true
	if host.house_camera_intro_tween != null and host.house_camera_intro_tween.is_valid():
		host.house_camera_intro_tween.kill()
	host.house_camera_intro_weight = 1.0
	host.house_camera_size_current = host._house_camera_size_target()
	host._apply_house_camera()
	for property in ["house_camera_target", "house_camera_yaw", "house_camera_pitch", "house_camera_distance", "house_camera_zoom_ratio", "house_camera_size_current"]:
		camera_defaults[property] = host.get(property)
	token_pose = host.house_root.get_node("LiliToken").transform
	baseline_environment = host.world_root.get_node("WorldEnvironment").environment.duplicate()
	sample_environment = baseline_environment.duplicate()
	sample_environment.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	sample_environment.ssao_radius = 0.28
	sample_environment.ssao_intensity = 1.05
	sample_environment.ambient_light_energy = 0.42
	sample_environment.ambient_light_color = Color("d8e4df")
	baseline_lights = _light_snapshot()
	_capture_materials()
	material_white_texture = _build_white_texture()
	_capture_material_details()
	_build_desktop()
	reference_environment = sample_environment.duplicate()
	reference_environment.ambient_light_energy = 0.30
	reference_environment.ambient_light_color = Color("889aaa")
	reference_builder = load("res://scripts/reference_workshop.gd").new()
	reference_root = reference_builder.build(self)
	_capture_reference_material_details()
	for node in host.house_root.find_children("ToyWorkbench*", "MeshInstance3D", true, false):
		node.set_meta("formal_room_base", true)
		reference_bases.append({"node": node, "visible": node.visible})
	joinery = load("res://scripts/toy_workshop_joinery.gd").new()
	joinery.build(self)
	atmosphere_environment = reference_environment.duplicate()
	atmosphere_environment.ambient_light_energy = 0.20
	atmosphere_environment.ssao_radius = 0.20
	atmosphere_environment.ssao_intensity = 1.3
	_apply()

func _light_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name in ["KeyLight", "FillLight"]:
		var light = host.world_root.get_node(name)
		result.append({"node": light, "light_color": light.light_color, "light_energy": light.light_energy, "light_angular_distance": light.light_angular_distance})
	return result

func _restore_lights(records: Array[Dictionary]) -> void:
	for record in records:
		for key in ["light_color", "light_energy", "light_angular_distance"]:
			record.node.set(key, record[key])

func set_mode(sample: bool) -> void:
	reference_mode = false
	material_detail_enabled = false
	mode_b = sample
	features.assign([true, true, true, false] if sample else [false, false, false, false])
	var restart := playing
	_stop_replay()
	_apply()
	if restart:
		replay()

func set_reference_mode() -> void:
	var restart := playing
	_stop_replay()
	reference_mode = true
	mode_b = true
	features.assign([true, false, true, false])
	# Formal baseline keeps depth of field off by default. It remains an
	# opt-in comparison toggle, but never obscures the room interfaces.
	reference_features.assign([true, true, true, false, true])
	material_detail_enabled = true
	_apply()
	if restart:
		replay()

func start_formal_workshop_preview(room_id: String = FORMAL_ROOM_ID) -> bool:
	var profile := FormalWorkshopProfile.for_room(room_id)
	if profile.has("error") or not is_instance_valid(reference_root):
		return false
	formal_preview_room_id = room_id
	formal_preview_state = "workshop"
	reference_root.scale = Vector3.ONE
	reference_root.set_meta("formal_room_id", room_id)
	reference_root.set_meta("projection_layer", "workshop")
	set_reference_mode()
	return true

func enter_formal_tv_dream_preview() -> Dictionary:
	if formal_preview_room_id.is_empty() or not is_instance_valid(reference_root):
		return {"ok": false, "error": "formal_preview_not_started"}
	formal_preview_state = "tv_dream"
	reference_root.scale = Vector3.ONE * 1.08
	reference_root.set_meta("projection_layer", "tv_dream")
	host.status_message = "电视梦境投射：房间轮廓保留，比例允许夸张。"
	return formal_preview_snapshot()

func return_formal_workshop_preview() -> Dictionary:
	if formal_preview_room_id.is_empty() or not is_instance_valid(reference_root):
		return {"ok": false, "error": "formal_preview_not_started"}
	formal_preview_state = "workshop"
	reference_root.scale = Vector3.ONE
	reference_root.set_meta("projection_layer", "workshop")
	host.status_message = "梦醒返回工坊：同一间实体房间恢复原构图。"
	return formal_preview_snapshot()

func formal_preview_snapshot() -> Dictionary:
	var profile := FormalWorkshopProfile.for_room(formal_preview_room_id)
	return {
		"ok": not profile.has("error"),
		"room_id": formal_preview_room_id,
		"state": formal_preview_state,
		"outline": profile.get("room_presentation", {}).get("main_furniture_outline", ""),
		"projection_layer": reference_root.get_meta("projection_layer", "") if is_instance_valid(reference_root) else ""
	}

func update_reference_view() -> void:
	if is_instance_valid(reference_root):
		reference_builder.update_view(host.camera.global_position)

func toggle_reference_feature(index: int) -> void:
	if not reference_mode or index < 0 or index >= reference_features.size():
		return
	var restart := playing
	_stop_replay()
	reference_features[index] = not reference_features[index]
	if index == 4:
		material_detail_enabled = reference_features[index]
	_apply()
	if restart:
		replay()

func toggle_refined_structure() -> void:
	var restart := playing
	_stop_replay()
	refined_structure = not refined_structure
	_apply()
	if restart:
		replay()

func set_material_detail(value: bool) -> void:
	material_detail_enabled = value
	if reference_mode and reference_features.size() > 4:
		reference_features[4] = value
	_apply()

func toggle_feature(index: int) -> void:
	if index < 0 or index >= features.size():
		return
	var restart := playing
	_stop_replay()
	features[index] = not features[index]
	mode_b = features.any(func(value: bool): return value)
	_apply()
	if restart:
		replay()

func _apply() -> void:
	joinery.set_enabled(false)
	joinery.refined = refined_structure
	decor_root.visible = features[0] and not reference_mode
	reference_root.visible = reference_mode and features[0]
	for record in reference_bases:
		record.node.visible = record.visible and not reference_root.visible
	update_reference_view()
	for record in material_records:
		var mesh: MeshInstance3D = record.node
		mesh.mesh = record.rounded_mesh if features[1] else record.original_mesh
		mesh.material_override = record.sample_override if features[1] else record.original_override
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i, record.sample_surfaces[i] if features[1] else record.original_surfaces[i])
	_apply_material_details()
	_apply_reference_material_details()
	joinery.set_enabled(reference_root.visible and reference_features[0])
	var atmosphere := reference_root.visible and reference_features[2]
	reference_builder.set_atmosphere(atmosphere)
	host.world_root.get_node("WorldEnvironment").environment = sample_environment if features[2] else baseline_environment
	if reference_mode and features[2]:
		host.world_root.get_node("WorldEnvironment").environment = reference_environment
	_restore_lights(baseline_lights)
	if features[2]:
		var key = host.world_root.get_node("KeyLight")
		key.light_color = Color("fff0d9")
		key.light_energy = 1.15
		key.light_angular_distance = 2.5
		var fill = host.world_root.get_node("FillLight")
		fill.light_color = Color("c4e7e3")
		fill.light_energy = 0.38
		if reference_mode:
			key.light_energy = 0.85
			fill.light_energy = 0.22
	if atmosphere:
		host.world_root.get_node("WorldEnvironment").environment = atmosphere_environment
		var key = host.world_root.get_node("KeyLight")
		key.light_color = Color("fff1d9")
		key.light_energy = 0.92
		key.light_angular_distance = 4.0
		var fill = host.world_root.get_node("FillLight")
		fill.light_color = Color("adc9df")
		fill.light_energy = 0.12
	var settings = host.presentation_settings
	settings.depth_of_field_enabled = true if features[3] else (saved_dof[0] if not mode_b else false)
	settings.depth_of_field_blur_strength = 1.5 if features[3] else saved_dof[1]
	settings.depth_of_field_focus_width = 0.40 if features[3] else saved_dof[2]
	if reference_mode:
		settings.depth_of_field_enabled = reference_features[3]
		settings.depth_of_field_blur_strength = 0.8 if reference_features[3] else 0.0
		settings.depth_of_field_focus_width = 0.40
	settings._apply_depth_of_field_state()
	host.status_message = "C：造型按钮切换新旧结构，原版移轴景深可独立关闭检查细节。R 重播拼装；拖拽旋转、滚轮缩放。"
	host._refresh_hud()

func reset_camera() -> void:
	for property in camera_defaults:
		host.set(property, camera_defaults[property])
	host._apply_house_camera()

func replay() -> void:
	_stop_replay()
	playing = true
	generation += 1
	var ticket := generation
	var token: Node3D = host.house_root.get_node("LiliToken")
	token.position = host._house_interaction_target_position("player:lili", entry)
	host.current_room_pos = entry
	host.animation_busy = true
	host.active_animation_kind = "room_drop"
	var assembly = load("res://scripts/toy_room_assembly.gd").new()
	assembly.toy_snap_enabled = reference_mode and reference_features[1]
	host.active_room_assembly = assembly
	assembly.prepare(host._find_room_instance_nodes(target), host.camera)
	var tween: Tween = host.create_tween()
	host.active_motion_tween = tween
	tween.tween_method(assembly.pose, 0.0, assembly.DURATION, maxf(0.001, assembly.DURATION * host.animation_duration_scale))
	tween.tween_interval(0.10 * host.animation_duration_scale)
	await tween.finished
	if closed or ticket != generation:
		return
	assembly.finish()
	host.active_room_assembly = null
	host.active_animation_kind = "room_entry"
	await host._animate_enter_room(target)

func finish_entry() -> void:
	playing = false
	host.house_camera_following = false
	host.house_root.get_node("LiliToken").transform = token_pose
	var presenter = host.house_root.get_node("LiliToken").get_node_or_null("Presenter")
	if presenter != null and presenter.has_method("play_state"):
		presenter.play_state("idle")
	host._complete_dynamic_effect()
	host._apply_current_room_cutaway()
	host._refresh_hud()

func _stop_replay() -> void:
	generation += 1
	if not playing:
		return
	playing = false
	host._cancel_dynamic_effect()
	host.current_room_pos = target
	host.house_root.get_node("LiliToken").transform = token_pose

func close() -> void:
	if closed:
		return
	_stop_replay()
	if is_instance_valid(reference_root):
		reference_root.scale = Vector3.ONE
	closed = true
	if joinery != null:
		joinery.close()
	for record in material_records:
		if is_instance_valid(record.node):
			record.node.mesh = record.original_mesh
			record.node.material_override = record.original_override
			for i in range(record.original_surfaces.size()):
				record.node.set_surface_override_material(i, record.original_surfaces[i])
	if is_instance_valid(decor_root):
		decor_root.free()
	if is_instance_valid(reference_root):
		reference_root.free()
	for record in reference_bases:
		if is_instance_valid(record.node):
			record.node.visible = record.visible
	host.world_root.get_node("WorldEnvironment").environment = saved_environment
	_restore_lights(saved_lights)
	var settings = host.presentation_settings
	settings.depth_of_field_enabled = saved_dof[0]
	settings.depth_of_field_blur_strength = saved_dof[1]
	settings.depth_of_field_focus_width = saved_dof[2]
	settings._apply_depth_of_field_state()
	host.camera.transform = saved_camera_transform
	host.camera.size = saved_camera_size
	for property in saved_house_camera:
		host.set(property, saved_house_camera[property])
	host.house_root.get_node("LiliToken").transform = saved_token_transform
	host.run_save_repository = saved_repository
	host.tactile_lab = null

func _finish_kind(mesh: MeshInstance3D) -> String:
	var node: Node = mesh
	var names := ""
	var finish := "painted_wood"
	while node != null and node != host.house_root:
		names += String(node.name).to_lower() + " "
		if node.has_meta("handmade_finish"):
			finish = str(node.get_meta("handmade_finish"))
		node = node.get_parent()
	if "lilitoken" in names:
		return "clay"
	if "cushion" in names or "pillow" in names or "couch" in names or "rug" in names or finish == "felt":
		return "felt"
	if "paper" in names or "book" in names:
		return "paper"
	if "cap" in names or "knob" in names or "junction" in names:
		return "plastic"
	return finish

func _sample_material(source: Material, kind: String) -> Material:
	if not source is StandardMaterial3D:
		return source
	var material: StandardMaterial3D = source.duplicate()
	material.roughness = {"painted_wood": 0.38, "plastic": 0.28, "clay": 0.84, "felt": 0.98, "paper": 0.90}.get(kind, 0.75)
	material.metallic = 0.0
	material.metallic_specular = 0.55 if kind in ["painted_wood", "plastic"] else 0.25
	return material

func _capture_materials() -> void:
	for node in host.house_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null:
			continue
		var kind := _finish_kind(mesh)
		var originals: Array[Material] = []
		var samples: Array[Material] = []
		for i in range(mesh.mesh.get_surface_count()):
			originals.append(mesh.get_surface_override_material(i))
			samples.append(_sample_material(mesh.get_active_material(i), kind))
		var rounded: Mesh = mesh.mesh
		if mesh.mesh is BoxMesh and kind in ["painted_wood", "plastic"]:
			var size: Vector3 = mesh.mesh.size
			rounded = _rounded_box(size, minf(size[size.min_axis_index()] * 0.15, 0.055))
		material_records.append({"node": mesh, "original_mesh": mesh.mesh, "rounded_mesh": rounded, "original_override": mesh.material_override,
			"sample_override": _sample_material(mesh.material_override, kind), "original_surfaces": originals, "sample_surfaces": samples})

func _build_white_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _asset_material_kind(mesh: MeshInstance3D) -> String:
	var names: String = str(mesh.get_path()).to_lower()
	if "lilitoken" in names or "clay" in names:
		return "clay"
	if ["cushion", "pillow", "couch", "armchair", "rug", "bed", "blanket", "curtain", "upholstery", "cuttingmat", "mat", "pad", "fabric"].any(func(part): return part in names):
		return "felt"
	if ["book", "paper", "page", "magazine", "note"].any(func(part): return part in names):
		return "paper"
	if ["lamp", "light", "metal", "handle", "knob", "hinge", "rail", "pipe", "hardware", "bolt", "washer"].any(func(part): return part in names):
		return "metal"
	if ["window", "glass", "mirror"].any(func(part): return part in names):
		return "glass"
	if ["pot", "ceramic", "vase", "mug", "dish"].any(func(part): return part in names):
		return "ceramic"
	if ["table", "desk", "shelf", "bookcase", "chair", "stool", "cabinet", "wood", "workbench"].any(func(part): return part in names):
		return "painted_wood"
	return "plastic"

func _material_kind_index(kind: String) -> int:
	return {"plastic": 0, "painted_wood": 1, "felt": 2, "metal": 3, "paper": 4, "ceramic": 5, "glass": 6, "clay": 2}.get(kind, 0)

func _detail_material(source: Material, kind: String) -> Material:
	if not source is StandardMaterial3D:
		return source
	var shader_material := ShaderMaterial.new()
	shader_material.shader = material_detail_shader
	var standard := source as StandardMaterial3D
	shader_material.set_shader_parameter("base_texture", standard.albedo_texture if standard.albedo_texture != null else material_white_texture)
	shader_material.set_shader_parameter("base_color", standard.albedo_color)
	shader_material.set_shader_parameter("material_kind", _material_kind_index(kind))
	shader_material.set_shader_parameter("micro_scale", 30.0 if kind in ["painted_wood", "felt"] else 46.0)
	shader_material.render_priority = standard.render_priority
	return shader_material

func _capture_material_details() -> void:
	material_detail_records.clear()
	for record in material_records:
		var mesh: MeshInstance3D = record.node
		var kind := _asset_material_kind(mesh)
		var detailed_surfaces: Array[Material] = []
		for i in range(mesh.mesh.get_surface_count()):
			var source: Material = record.original_surfaces[i]
			if source == null:
				source = mesh.mesh.surface_get_material(i)
			detailed_surfaces.append(_detail_material(source, kind))
		var detailed_override: Material = _detail_material(record.original_override, kind)
		material_detail_records.append({"node": mesh, "kind": kind, "original": record.original_override, "detailed": detailed_override, "original_surfaces": record.original_surfaces, "detailed_surfaces": detailed_surfaces})

func _apply_material_details() -> void:
	for record in material_detail_records:
		var mesh: MeshInstance3D = record.node
		if reference_mode and material_detail_enabled:
			if record.original != null and record.detailed != null:
				mesh.material_override = record.detailed
			for i in range(mesh.mesh.get_surface_count()):
				if record.detailed_surfaces[i] != null:
					mesh.set_surface_override_material(i, record.detailed_surfaces[i])

func _capture_reference_material_details() -> void:
	reference_material_detail_records.clear()
	if not is_instance_valid(reference_root):
		return
	for node in reference_root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null:
			continue
		var kind := _asset_material_kind(mesh)
		var originals: Array[Material] = []
		var detailed: Array[Material] = []
		for i in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.get_surface_override_material(i)
			originals.append(source)
			if source == null:
				source = mesh.mesh.surface_get_material(i)
			detailed.append(_detail_material(source, kind))
		reference_material_detail_records.append({"node": mesh, "kind": kind, "original": mesh.material_override, "detailed": _detail_material(mesh.material_override, kind), "original_surfaces": originals, "detailed_surfaces": detailed})

func _apply_reference_material_details() -> void:
	if not is_instance_valid(reference_root):
		return
	var enabled := reference_mode and material_detail_enabled
	for record in reference_material_detail_records:
		var mesh: MeshInstance3D = record.node
		mesh.material_override = record.detailed if enabled and record.detailed != null else record.original
		for i in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(i, record.detailed_surfaces[i] if enabled and record.detailed_surfaces[i] != null else record.original_surfaces[i])

func _box(parent: Node3D, name: String, position: Vector3, size: Vector3, color: String, roughness := 0.65) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.add_to_group(&"workshop_decor")
	node.mesh = _rounded_box(size, minf(size[size.min_axis_index()] * 0.2, 0.06))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = roughness
	node.material_override = material
	parent.add_child(node)
	node.position = position
	return node

func _build_desktop() -> void:
	decor_root = Node3D.new()
	decor_root.name = "TactileDesktop"
	host.house_root.add_child(decor_root)
	var benches = host.house_root.find_children("ToyWorkbench", "MeshInstance3D", true, false)
	var bounds := AABB(Vector3(-4, -0.8, -4), Vector3(8, 0.2, 8))
	if not benches.is_empty():
		var bench: MeshInstance3D = benches[0]
		bounds = bench.global_transform * bench.get_aabb()
	var center := bounds.get_center()
	var top := bounds.position.y - 0.03
	_box(decor_root, "Desktop", Vector3(center.x, top - 0.15, center.z), Vector3(bounds.size.x + 5.0, 0.3, bounds.size.z + 5.0), "a99885", 0.92)
	var x := bounds.end.x + 0.8
	var z := bounds.position.z + 0.6
	_box(decor_root, "CoralBlock", Vector3(x, top + 0.26, z), Vector3(0.52, 0.52, 0.52), "eb947d", 0.38).rotation.y = 0.2
	_box(decor_root, "YellowBlock", Vector3(x + 0.35, top + 0.15, z + 0.7), Vector3(0.64, 0.3, 0.45), "eac863", 0.38).rotation.y = -0.3
	_box(decor_root, "TealBlock", Vector3(x, top + 0.15, z + 1.3), Vector3(0.3, 0.3, 0.6), "72b4aa", 0.38)
	var papers := Node3D.new()
	decor_root.add_child(papers)
	papers.position = Vector3(bounds.position.x - 1.05, top, center.z)
	papers.rotation.y = -0.2
	for i in range(3):
		_box(papers, "StickerPaper%d" % i, Vector3(i * 0.04, 0.016 + i * 0.028, 0), Vector3(1.0, 0.025, 1.3), "eee6cd", 0.9)
	for i in range(3):
		_box(papers, "Sticker%d" % i, Vector3(-0.22 + i * 0.24, 0.086, 0.12), Vector3(0.16, 0.006, 0.40), ["df8b81", "71aaa1", "dbbd61"][i], 0.88)
	var tray := Node3D.new()
	decor_root.add_child(tray)
	tray.position = Vector3(center.x + 0.7, top, bounds.end.z + 1.0)
	_box(tray, "TrayBase", Vector3(0, 0.045, 0), Vector3(1.6, 0.09, 0.9), "729c99", 0.35)
	for side in [-1, 1]:
		_box(tray, "TrayLong%d" % side, Vector3(0, 0.19, side * 0.43), Vector3(1.6, 0.3, 0.09), "92b9ae", 0.35)
		_box(tray, "TrayShort%d" % side, Vector3(side * 0.75, 0.19, 0), Vector3(0.1, 0.3, 0.8), "92b9ae", 0.35)

func _rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	# Rounded cuboid geometry; shared boundaries and normals retain a real silhouette.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var core := half - Vector3.ONE * radius
	for axis in range(3):
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var us := [-half[u_axis], -half[u_axis] + radius * 0.293, -core[u_axis], core[u_axis], half[u_axis] - radius * 0.293, half[u_axis]]
		var vs := [-half[v_axis], -half[v_axis] + radius * 0.293, -core[v_axis], core[v_axis], half[v_axis] - radius * 0.293, half[v_axis]]
		for side in [-1.0, 1.0]:
			for i in range(5):
				for j in range(5):
					var corners := [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i+1,j+1), Vector2i(i,j+1)]
					for index in ([0,2,1,0,3,2] if side > 0 else [0,1,2,0,2,3]):
						var corner: Vector2i = corners[index]
						var point := Vector3.ZERO
						point[axis] = side * half[axis]
						point[u_axis] = us[corner.x]
						point[v_axis] = vs[corner.y]
						var inside := point.clamp(-core, core)
						var normal := (point - inside).normalized()
						st.set_normal(normal)
						st.set_uv(Vector2(float(corner.x) / 5.0, float(corner.y) / 5.0))
						st.add_vertex(inside + normal * radius)
	return st.commit()
