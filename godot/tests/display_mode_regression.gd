extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.display_resolution_index = 3
	game.display_fullscreen = true
	await game._apply_display_settings(false)
	await process_frame
	var mode := DisplayServer.window_get_mode()
	var hud = game.get_node("HUD/HUDRoot")
	var visible_size: Vector2 = game.get_viewport().get_visible_rect().size
	var world_rect: Rect2 = hud.get_world_view_rect()
	var can_control_window := DisplayServer.get_name() != "headless"
	if can_control_window:
		_check(mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN], "standalone game must enter fullscreen mode")
	_check(hud.ui_scale > 0.0 and hud.ui_offset.x >= 0.0 and hud.ui_offset.y >= 0.0, "fullscreen HUD transform must remain valid")
	_check(Rect2(Vector2.ZERO, visible_size).encloses(world_rect), "fullscreen world viewport must remain inside the visible canvas")
	# Headless/Dummy 渲染器没有根视口纹理；真实窗口渲染时仍验证截图内容。
	var viewport_texture: Texture2D = game.get_viewport().get_texture()
	if DisplayServer.get_name() != "headless" and viewport_texture != null:
		var screenshot: Image = viewport_texture.get_image()
		_check(not screenshot.is_empty(), "fullscreen frame capture must not be empty")
		if not screenshot.is_empty():
			screenshot.save_png("user://display_fullscreen_check.png")
	game.display_fullscreen = false
	game.display_resolution_index = 2
	await game._apply_display_settings(false)
	await process_frame
	if can_control_window:
		_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "game must return to windowed mode")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("DISPLAY_MODE_REGRESSION: PASS fullscreen windowed responsive HUD")
		quit(0)
	else:
		for failure: String in failures:
			push_error("DISPLAY_MODE_REGRESSION: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
