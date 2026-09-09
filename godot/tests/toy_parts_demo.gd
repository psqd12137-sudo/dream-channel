extends SceneTree

# Isolated visual capture using the same choreography as formal placement.
const OUT := "res://../output/toy-parts-offscreen-slow"
const PLAYBACK_DURATION_SCALE := 1.5
var game: Node3D
var pieces: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://channel_3d.tscn").instantiate()
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new(OUT + "/isolated.json", game.EXE_SOURCE_ID)
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	root.size = Vector2i(1280, 720)
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)
	var hall: Dictionary = game._find_catalog_room("hall")
	var target := Vector2i.ZERO
	for cell: Vector2i in game.room_rules.frontiers():
		var rotations: Array = game.room_rules.valid_rotations(cell, hall)
		if not rotations.is_empty():
			game.room_rules.place(cell, hall, rotations[0])
			target = cell
			break
	# Public art sample: furniture is deliberately visible in this isolated demo.
	game.room_rules.set_instance_flag(target, "visited", true)
	game.room_rules.set_instance_flag(target, "revealed", true)
	game.build_house_world()
	game.status_message = "卡通拼装 · 停——砰！咔咔咔——嗒！"
	game._refresh_hud()
	game.presentation_settings.depth_of_field_enabled = false
	game.presentation_settings._apply_depth_of_field_state()
	await create_timer(0.5).timeout
	var module: Node3D = game._find_room_instance_nodes(target)[0]
	var assembly = load("res://scripts/toy_room_assembly.gd").new()
	game.set_process(false)
	game.camera.size *= 1.18
	game.camera.position.y += 2.0
	assembly.prepare([module], game.camera)
	pieces = assembly.pieces
	print("OFFSCREEN_CHECK: shared approved choreography")
	var frame_count := int(ceil(78 * PLAYBACK_DURATION_SCALE))
	for frame in range(frame_count):
		var time := float(frame) / (30.0 * PLAYBACK_DURATION_SCALE)
		assembly.pose(time * PLAYBACK_DURATION_SCALE)
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(OUT + "/frame_%03d.png" % frame)
		if result != OK:
			quit(1)
			return
	for piece: Dictionary in pieces:
		if not (piece.node.transform as Transform3D).is_equal_approx(piece.pose):
			push_error("Part did not settle exactly: " + str(piece.node.name))
			quit(1)
			return
	print("TOY_PARTS_DEMO: PASS parts=", pieces.size(), " frames=", frame_count, " final transforms exact")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	quit(0)
