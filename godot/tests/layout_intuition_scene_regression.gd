extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var save := "user://channel_run_v1.json"
	var existed := FileAccess.file_exists(save)
	var before := FileAccess.get_file_as_bytes(save) if existed else PackedByteArray()
	var lab = load("res://scenes/layout_intuition_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	assert(lab.geometry.get_child_count() == 1)
	var position_on_screen: Vector2 = lab.camera.unproject_position(lab._point(Vector2i(1,0),0))
	var motion := InputEventMouseMotion.new()
	motion.position = position_on_screen
	lab._unhandled_input(motion)
	assert(lab.hint.text.contains("形成回路"))
	var click := InputEventMouseButton.new()
	click.position = position_on_screen
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	lab._unhandled_input(click)
	assert(lab.model.rules.placed.has(Vector2i(1,0)), "screen picking places previewed room")
	lab.probing = true
	lab.obstruction = true
	lab._draw_route()
	assert(lab.preview_root.get_child_count() == 0, "route mode clears proposed geometry")
	lab._rebuild()
	assert(lab.hint.text.contains("2 步"))
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/layout-intuition.png")
	assert(FileAccess.file_exists(save) == existed)
	if existed:
		assert(FileAccess.get_file_as_bytes(save) == before, "lab must not change formal save")
	lab.queue_free()
	await process_frame
	print("LAYOUT_INTUITION_SCENE: PASS")
	quit()
