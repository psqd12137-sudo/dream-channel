extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var error := change_scene_to_file("res://channel_3d.tscn")
	_check(error == OK, "main scene must open")
	await process_frame
	await process_frame
	var game := current_scene as Node3D
	_check(game != null and game.name == "Channel3D", "test must start on the title scene")
	if game == null:
		_finish()
		return
	var hud := game.get_node("HUD/HUDRoot") as Control
	hud.sync_layout()
	_click(hud, hud.HOME_TESTS_RECT)
	_check(game.home_tests_open, "backend test desk button must expand")
	_click(hud, hud.HOME_TEST_ASSET_EDITOR_RECT)
	await process_frame
	await process_frame
	var editor := current_scene as Node3D
	_check(editor != null and editor.name == "AssetEditor3D", "asset editor backend button must change to the full editor scene")
	if editor != null:
		var return_button := editor.get_node_or_null("UI/ReturnHome") as Button
		_check(return_button != null, "asset editor must show the return-to-title button")
		if return_button != null:
			return_button.emit_signal("pressed")
			await process_frame
			await process_frame
			_check(current_scene != null and current_scene.name == "Channel3D", "asset editor return button must restore the title scene")
	_finish()


func _click(hud: Control, design_rect: Rect2) -> void:
	var point: Vector2 = hud.ui_offset + (design_rect.position + design_rect.size * 0.5) * hud.ui_scale
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	hud._gui_input(press)
	if not hud.is_inside_tree():
		return
	var release := InputEventMouseButton.new()
	release.position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	hud._gui_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_ASSET_EDITOR_BACKEND_ENTRY: PASS title editor return-title")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_ASSET_EDITOR_BACKEND_ENTRY: %s" % failure)
		quit(1)
