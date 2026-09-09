extends SceneTree

const OUT := "res://../output/tactile-lab"
var game

func _init() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://channel_3d.tscn").instantiate()
	root.add_child(game)
	await process_frame
	root.size = Vector2i(1280, 800)
	game.start_tactile_lab()
	if "--reference" in OS.get_cmdline_user_args():
		game.tactile_lab.set_reference_mode()
		await capture("C-default")
		game.tactile_lab.toggle_reference_feature(2)
		await capture("C-light-off")
		game.tactile_lab.toggle_reference_feature(2)
		game.tactile_lab.toggle_reference_feature(0)
		await capture("C-joinery-off")
		game.tactile_lab.toggle_reference_feature(0)
		game.tactile_lab.set_mode(false)
		await capture("C-baseline")
		game.tactile_lab.set_reference_mode()
		for i in range(4):
			game.tactile_lab.reset_camera()
			game.orbit_house_camera(Vector2(float(i) * PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0))
			await capture("C-view%d" % i)
			game.zoom_house_camera(Vector2.ZERO, 0.01)
			await capture("C-view%d-near" % i)
			game.zoom_house_camera(Vector2.ZERO, 100)
			await capture("C-view%d-far" % i)
		game.tactile_lab.reset_camera()
		game.house_camera_pitch = 0.34
		game._apply_house_camera()
		await capture("C-low-angle")
		game.tactile_lab.reset_camera()
		game.tactile_lab.replay()
		await capture("C-drop")
		await create_timer(4).timeout
		await capture("C-ready")
		if "--benchmark" in OS.get_cmdline_user_args():
			await benchmark_reference()
		game.go_home()
		game.queue_free()
		await process_frame
		print("REFERENCE_CAPTURE: PASS")
		quit()
		return
	await capture("B-default")
	game.tactile_lab.set_mode(false)
	await capture("A-default")
	game.tactile_lab.set_mode(true)
	for i in range(4):
		game.tactile_lab.reset_camera()
		game.orbit_house_camera(Vector2(float(i) * PI * 0.5 / game.CAMERA_ORBIT_SENSITIVITY, 0))
		await capture("B-view%d" % i)
		game.zoom_house_camera(Vector2.ZERO, 0.01)
		await capture("B-view%d-near" % i)
		game.zoom_house_camera(Vector2.ZERO, 100)
		await capture("B-view%d-far" % i)
	game.tactile_lab.reset_camera()
	game.zoom_house_camera(Vector2.ZERO, 0.01)
	await capture("B-near")
	game.tactile_lab.toggle_feature(3)
	await capture("DOF-near")
	game.zoom_house_camera(Vector2.ZERO, 100)
	await capture("DOF-far")
	game.tactile_lab.reset_camera()
	game.tactile_lab.set_mode(true)
	game.tactile_lab.replay()
	await capture("B-drop")
	await capture("B-land")
	await create_timer(3).timeout
	await capture("B-ready")
	if "--benchmark" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		var report := {}
		for sample in [false, true]:
			game.tactile_lab.set_mode(sample)
			await create_timer(3.0).timeout
			var frames: Array[float] = []
			var start := Time.get_ticks_usec()
			var previous := start
			while Time.get_ticks_usec() - start < 30000000:
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append(float(now - previous) / 1000.0)
				previous = now
			var total := 0.0
			for value in frames:
				total += value
			frames.sort()
			var name := "B" if sample else "A"
			report[name] = {"mean_ms": total / frames.size(), "p95_ms": frames[int(frames.size() * 0.95)], "frames": frames.size()}
			print("TACTILE_PERF ", name, ": ", report[name])
		var file := FileAccess.open(OUT + "/performance.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	game.go_home()
	game.queue_free()
	await process_frame
	print("TACTILE_CAPTURE: PASS")
	quit()

func benchmark_reference() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var report := {}
	for preset in ["A", "C-light-off", "C"]:
		if preset == "A":
			game.tactile_lab.set_mode(false)
		else:
			game.tactile_lab.set_reference_mode()
			if game.tactile_lab.reference_features[2] != (preset == "C"):
				game.tactile_lab.toggle_reference_feature(2)
		await create_timer(3).timeout
		var frames: Array[float] = []
		var start := Time.get_ticks_usec()
		var previous := start
		while Time.get_ticks_usec() - start < 30000000:
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append(float(now - previous) / 1000.0)
			previous = now
		var total := 0.0
		for value in frames:
			total += value
		frames.sort()
		report[preset] = {"mean_ms": total / frames.size(), "p95_ms": frames[int(frames.size() * 0.95)], "frames": frames.size()}
		print("REFERENCE_PERF ", preset, " ", report[preset])
	var file := FileAccess.open(OUT + "/reference-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
