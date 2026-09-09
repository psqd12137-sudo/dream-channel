extends SceneTree
var failures: Array[String] = []
var capture := "--capture" in OS.get_cmdline_user_args()

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://formal_cartoon_test.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	game.begin_build(game.room_rules.frontiers()[0])
	game.animation_duration_scale = 1.0
	game.place_selected_offer()
	var target: Vector2i = game.pending_room_pos
	var assembly = game.active_room_assembly
	check(assembly != null, "formal build must use the shared approved animation")
	if assembly != null:
		for piece: Dictionary in assembly.pieces:
			check(assembly.lowest_screen_point(piece.node) < -48.0, "whole part must begin above viewport: " + str(piece.node.name))
	if capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../output/formal-cartoon"))
		for frame in range(108):
			await create_timer(1.0 / 30.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../output/formal-cartoon/frame_%03d.png" % frame)
	else:
		await create_timer(0.75).timeout
		check(game.animation_busy and game.active_animation_kind == "room_drop", "approved slow assembly must still be dropping at 0.75 seconds")
	var deadline := Time.get_ticks_msec() + 7000
	while game.animation_busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.animation_busy and game.phase == "room_ready", "assembly and entry must finish at room_ready")
	check(game.current_room_pos == target, "actor must enter the newly assembled room")
	check(game.active_room_assembly == null, "animation must release shared controller")
	game.phase = "explore"
	game.begin_build(game.room_rules.frontiers()[0])
	game.place_selected_offer()
	await create_timer(0.75).timeout
	game.go_home()
	await create_timer(0.1).timeout
	check(game.phase == "home" and game.active_room_assembly == null and not game.animation_busy, "interrupted assembly must clean up")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	for failure: String in failures:
		push_error("FORMAL_CARTOON: " + failure)
	print("FORMAL_CARTOON: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
