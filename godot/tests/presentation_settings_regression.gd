extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	var hud: Control = game.get_node("HUD/HUDRoot")
	var dof_material := game.world_container.material as ShaderMaterial
	_check(dof_material != null, "world viewport container must own the depth-of-field material")
	_check(game.world_viewport.use_taa == game.taa_enabled, "viewport TAA must match the presentation setting on boot")
	if dof_material != null:
		_check(bool(dof_material.get_shader_parameter("effect_enabled")) == game.depth_of_field_enabled, "depth-of-field shader must match the presentation setting on boot")

	var initial_taa: bool = game.taa_enabled
	_click(hud, hud.HOME_TAA_RECT)
	_check(hud.settings_panel_open, "home画面设置按钮 must open the settings panel")
	_click(hud, hud.SETTINGS_TAA_RECT)
	_check(game.taa_enabled != initial_taa and game.world_viewport.use_taa == game.taa_enabled, "settings panel TAA toggle must update the 3D viewport")

	var initial_dof: bool = game.depth_of_field_enabled
	_click(hud, hud.SETTINGS_DOF_RECT)
	_check(game.depth_of_field_enabled != initial_dof, "settings panel depth-of-field toggle must update the setting")
	if dof_material != null:
		_check(bool(dof_material.get_shader_parameter("effect_enabled")) == game.depth_of_field_enabled, "settings panel depth-of-field toggle must update the shader")
	var initial_dof_blur: float = game.depth_of_field_blur_strength
	_drag_slider(hud, hud.SETTINGS_DOF_BLUR_RECT, 0.75)
	_check(not is_equal_approx(game.depth_of_field_blur_strength, initial_dof_blur), "settings panel depth-of-field blur slider must update the parameter")
	if dof_material != null:
		_check(is_equal_approx(float(dof_material.get_shader_parameter("max_blur_pixels")), game.depth_of_field_blur_strength), "depth-of-field blur control must update the shader")
	var initial_dof_focus: float = game.depth_of_field_focus_width
	_drag_slider(hud, hud.SETTINGS_DOF_FOCUS_RECT, 0.65)
	_check(not is_equal_approx(game.depth_of_field_focus_width, initial_dof_focus), "settings panel depth-of-field focus slider must update the parameter")
	if dof_material != null:
		_check(is_equal_approx(float(dof_material.get_shader_parameter("focus_half_width")), game.depth_of_field_focus_width), "depth-of-field focus control must update the shader")
	var initial_pixel_filter: bool = game.pixel_filter_enabled
	_click(hud, hud.SETTINGS_PIXEL_RECT)
	_check(game.pixel_filter_enabled != initial_pixel_filter, "settings panel pixel filter toggle must update the setting")
	var pixel_material: ShaderMaterial = game.world_container.material as ShaderMaterial
	_check(pixel_material != null and pixel_material.shader != null and pixel_material.shader.resource_path.ends_with("pixel_art_3d.gdshader"), "settings panel pixel filter toggle must apply the pixel shader")
	var initial_pixel_size: float = game.pixel_filter_pixel_size
	_drag_slider(hud, hud.SETTINGS_PIXEL_SIZE_RECT, 0.55)
	_check(not is_equal_approx(game.pixel_filter_pixel_size, initial_pixel_size), "settings panel pixel-size slider must update the parameter")
	var initial_palette_steps: float = game.pixel_filter_palette_steps
	_drag_slider(hud, hud.SETTINGS_PIXEL_PALETTE_RECT, 0.35)
	_check(not is_equal_approx(game.pixel_filter_palette_steps, initial_palette_steps), "settings panel palette slider must update the parameter")
	pixel_material = game.world_container.material as ShaderMaterial
	if pixel_material != null:
		_check(is_equal_approx(float(pixel_material.get_shader_parameter("pixel_size")), game.pixel_filter_pixel_size), "pixel-size control must update the pixel shader")
		_check(is_equal_approx(float(pixel_material.get_shader_parameter("palette_steps")), game.pixel_filter_palette_steps), "palette control must update the pixel shader")
	_click(hud, hud.SETTINGS_PIXEL_RECT)
	_check(game.pixel_filter_enabled == initial_pixel_filter, "settings panel pixel filter toggle must restore the setting")
	_click(hud, hud.SETTINGS_CLOSE_RECT)
	_check(not hud.settings_panel_open, "settings panel close button must close the panel")

	_check(game.open_combat_test_mode(), "settings overlay regression must enter the combat test desk")
	_check(game.start_test_combat("manual"), "settings overlay regression must start a combat test")
	await process_frame
	_click(hud, hud.SETTINGS_TOGGLE_RECT)
	_check(hud.settings_panel_open, "combat top-bar settings button must open the settings panel")
	await process_frame
	_check(not game.battle_feedback_root.visible, "settings panel must suppress intent and feedback overlays")
	_click(hud, hud.SETTINGS_CLOSE_RECT)
	await process_frame
	_check(not hud.settings_panel_open and game.battle_feedback_root.visible, "closing settings must restore the combat feedback layer")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PRESENTATION_SETTINGS: PASS panel TAA DOF pixel parameters and feedback suppression")
		quit(0)
	else:
		for failure: String in failures:
			push_error("PRESENTATION_SETTINGS: %s" % failure)
		quit(1)


func _click(hud: Control, design_rect: Rect2) -> void:
	var press := InputEventMouseButton.new()
	press.position = hud.ui_offset + design_rect.get_center() * hud.ui_scale
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._gui_input(press)


func _drag_slider(hud: Control, design_rect: Rect2, ratio: float) -> void:
	var track_width: float = design_rect.size.x - hud.SETTINGS_SLIDER_TRACK_LEFT - hud.SETTINGS_SLIDER_TRACK_RIGHT
	var design_start := design_rect.position + Vector2(hud.SETTINGS_SLIDER_TRACK_LEFT, design_rect.size.y * 0.5)
	var design_end := design_rect.position + Vector2(hud.SETTINGS_SLIDER_TRACK_LEFT + track_width * ratio, design_rect.size.y * 0.5)
	var press := InputEventMouseButton.new()
	press.position = hud.ui_offset + design_start * hud.ui_scale
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = hud.ui_offset + design_end * hud.ui_scale
	motion.relative = (design_end - design_start) * hud.ui_scale
	hud._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.position = hud.ui_offset + design_end * hud.ui_scale
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	hud._gui_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
