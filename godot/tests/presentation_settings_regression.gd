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
	var initial_pixel_filter: bool = game.pixel_filter_enabled
	_click(hud, hud.SETTINGS_PIXEL_RECT)
	_check(game.pixel_filter_enabled != initial_pixel_filter, "settings panel pixel filter toggle must update the setting")
	var pixel_material: ShaderMaterial = game.world_container.material as ShaderMaterial
	_check(pixel_material != null and pixel_material.shader != null and pixel_material.shader.resource_path.ends_with("pixel_art_3d.gdshader"), "settings panel pixel filter toggle must apply the pixel shader")
	_click(hud, hud.SETTINGS_PIXEL_RECT)
	_check(game.pixel_filter_enabled == initial_pixel_filter, "settings panel pixel filter toggle must restore the setting")
	_click(hud, hud.SETTINGS_CLOSE_RECT)
	_check(not hud.settings_panel_open, "settings panel close button must close the panel")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PRESENTATION_SETTINGS: PASS panel TAA DOF pixel viewport-shader binding")
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


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
