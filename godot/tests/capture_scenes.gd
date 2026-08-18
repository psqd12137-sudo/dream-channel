extends SceneTree


func _init() -> void:
	_capture_flow.call_deferred()


func _capture_flow() -> void:
	root.size = Vector2i(1280, 800)
	var packed: PackedScene = load("res://main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await RenderingServer.frame_post_draw
	_save("res://artifacts/house-scene.png")

	scene._start_combat(scene._first_combat_room())
	await process_frame
	# CanvasItem 在切换整套动态 HUD 时可能需要下一帧才完成全区域重绘。
	await process_frame
	await RenderingServer.frame_post_draw
	_save("res://artifacts/combat-scene.png")
	print("CHANNEL_CAPTURE: PASS house-scene.png combat-scene.png")
	quit(0)


func _save(path: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save %s: %s" % [path, error_string(error)])
