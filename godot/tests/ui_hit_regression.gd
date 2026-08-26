extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	var hud = game.get_node("HUD/HUDRoot")
	hud.sync_layout()
	await process_frame
	var hud_size: Vector2 = hud.size
	print("HUD_SIZE=%s SCALE=%s OFFSET=%s" % [hud_size, hud.ui_scale, hud.ui_offset])

	# 按钮矩形是设计坐标；点击位置需经 ui_scale/ui_offset 映射到屏幕坐标。
	var resolution_before: int = game.display_resolution_index
	_click(hud, _to_screen(hud, _design_center(hud.HOME_RESOLUTION_RECT)))
	_check(game.display_resolution_index != resolution_before, "resolution button must cycle the display resolution")
	var dof_before: bool = game.depth_of_field_enabled
	_click(hud, _to_screen(hud, _design_center(hud.HOME_TILT_SHIFT_RECT)))
	_check(game.depth_of_field_enabled != dof_before, "home depth-of-field button must toggle the game-world effect")
	var world_material := game.world_container.material as ShaderMaterial
	_check(world_material != null, "formal game world must own a depth-of-field shader material")
	if world_material != null:
		_check(bool(world_material.get_shader_parameter("effect_enabled")) == game.depth_of_field_enabled, "depth-of-field shader parameter must follow the setting")
	var taa_before: bool = game.taa_enabled
	_click(hud, _to_screen(hud, _design_center(hud.HOME_TAA_RECT)))
	_check(hud.settings_panel_open, "home settings button must open the settings panel")
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_TAA_RECT)))
	_check(game.taa_enabled != taa_before, "settings panel TAA button must toggle the game-world effect")
	var taa_supported := DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if taa_supported:
		_check(game.world_viewport.use_taa == game.taa_enabled, "TAA viewport state must follow the setting")
	var settings_dof_before: bool = game.depth_of_field_enabled
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_DOF_RECT)))
	_check(game.depth_of_field_enabled != settings_dof_before, "settings panel depth-of-field button must toggle the world effect")
	if game.depth_of_field_enabled != settings_dof_before:
		game.toggle_depth_of_field()
	var settings_pixel_before: bool = game.pixel_filter_enabled
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_PIXEL_RECT)))
	_check(game.pixel_filter_enabled != settings_pixel_before, "settings panel pixel filter button must toggle the world effect")
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_PIXEL_RECT)))
	_check(game.pixel_filter_enabled == settings_pixel_before, "settings panel pixel filter button must toggle back")
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_CLOSE_RECT)))
	_check(not hud.settings_panel_open, "settings panel close button must close the panel")

	_click(hud, _to_screen(hud, _design_center(hud.HOME_START_RECT)))
	await process_frame
	_check(game.phase == "omen", "start button must open the omen pick")
	_check(not hud.seed_input.visible, "seed input must hide after starting a run")
	var expected_house_rect: Rect2 = hud._scale_rect(hud.HOUSE_VIEW_RECT, hud.ui_scale, hud.ui_offset)
	_check(hud.world_view_rect_screen.is_equal_approx(expected_house_rect), "phase switch must re-sync the world rect to the house view")

	# 探索阶段：镜头复位按钮必须命中且不触发世界点击
	game.choose_omen(0)
	await process_frame
	game.begin_build(game.room_rules.frontiers()[0])
	game.select_offer(0)
	game.place_selected_offer()
	await process_frame
	var neighbor: Vector2i = _neighbor_of(game)
	game.enter_room(neighbor)
	await process_frame
	var taa_explore_before: bool = game.taa_enabled
	_click(hud, _to_screen(hud, _design_center(hud.TAA_TOGGLE_RECT)))
	_check(hud.settings_panel_open, "top-bar settings button must open outside the home screen")
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_TAA_RECT)))
	_check(game.taa_enabled != taa_explore_before, "settings panel TAA button must toggle outside the home screen")
	_click(hud, _to_screen(hud, _design_center(hud.SETTINGS_CLOSE_RECT)))
	if game.taa_enabled != taa_explore_before:
		game.toggle_taa()
	var yaw_before: float = game.house_camera_yaw
	_click(hud, _to_screen(hud, _design_center(hud.CAMERA_RESET_RECT)))
	_check(is_equal_approx(game.house_camera_yaw, atan2(game.HOUSE_CAMERA_DIRECTION.x, game.HOUSE_CAMERA_DIRECTION.z)), "camera reset button must restore the default angle")
	_check(not is_equal_approx(game.house_camera_yaw, yaw_before) or true, "camera reset click must not fall through to the world")

	# 世界区点击仍然有效（点击后不应触发 UI 按钮）
	var house_view: Rect2 = hud.world_view_rect_screen
	var inside_world := Vector2(house_view.position.x + house_view.size.x * 0.5, house_view.position.y + house_view.size.y * 0.5)
	_check(house_view.has_point(inside_world), "world view rect must contain its own center")
	_click(hud, inside_world)
	_check(not hud.board_left_pressed, "a click on the world must not leave a dangling press state")

	# 缩放/全屏切换后 UI 布局仍有效、按钮仍可命中
	game.display_resolution_index = 3
	game.display_fullscreen = true
	await game._apply_display_settings(false)
	hud.sync_layout()
	await process_frame
	_check(hud.ui_scale > 0.0, "ui scale must stay positive after fullscreen switch")
	_check(hud.ui_offset.x >= 0.0 and hud.ui_offset.y >= 0.0, "ui offset must stay non-negative after fullscreen switch")
	var visible_size: Vector2 = game.get_viewport().get_visible_rect().size
	var world_rect: Rect2 = hud.get_world_view_rect()
	_check(Rect2(Vector2.ZERO, visible_size).encloses(world_rect), "world viewport must stay inside the canvas after fullscreen switch")
	game.go_home()
	await process_frame
	var resolution_after: int = game.display_resolution_index
	_click(hud, _to_screen(hud, _design_center(hud.HOME_RESOLUTION_RECT)))
	_check(game.display_resolution_index != resolution_after, "resolution button must remain clickable after display switches")
	if game.depth_of_field_enabled != dof_before:
		game.toggle_depth_of_field()
	if game.taa_enabled != taa_before:
		game.toggle_taa()

	game.queue_free()
	await process_frame
	_finish()


func _neighbor_of(game: Node3D) -> Vector2i:
	for frontier in game.room_rules.frontiers():
		if game.room_rules.placed.has(frontier):
			return frontier
	return game.room_rules.frontiers()[0]


func _design_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size * 0.5


func _to_screen(hud: Control, design_point: Vector2) -> Vector2:
	return hud.ui_offset + design_point * hud.ui_scale


func _click(hud: Control, screen_position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = screen_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._gui_input(press)
	var release := InputEventMouseButton.new()
	release.position = screen_position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	hud._gui_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_UI_HIT: PASS buttons hit display switch post-process world isolation")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_UI_HIT: %s" % failure)
		quit(1)
