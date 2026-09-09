extends SceneTree

# Isolated visual prototype. No changes to the formal placement flow.
const OUT := "res://../output/toy-parts-demo"
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
	game.status_message = "零件拼装样板 · 同时下落，依次卡合"
	game._refresh_hud()
	game.presentation_settings.depth_of_field_enabled = false
	game.presentation_settings._apply_depth_of_field_state()
	await create_timer(0.5).timeout
	var module: Node3D = game._find_room_instance_nodes(target)[0]
	var index := 0
	for child: Node in module.get_children():
		if not child is Node3D or not child.visible or child is Label3D:
			continue
		var name_lower := String(child.name).to_lower()
		var landing := 0.70 + float(index % 7) * 0.055
		if "base" in name_lower:
			landing = 0.35 + float(index % 3) * 0.035
		elif "floor" in name_lower:
			landing = 0.49 + float(index % 3) * 0.035
		elif "prop" in name_lower or "furniture" in name_lower:
			landing = 1.02 + float(index % 4) * 0.04
		pieces.append({"node": child, "pose": child.transform, "landing": landing,
			"offset": Vector3(sin(index * 2.4) * 0.6, 2.8 + float(index % 4) * 0.3, cos(index * 2.4) * 0.6),
			"axis": Vector3(1, 0.3, sin(index)).normalized(), "angle": deg_to_rad(18 + index % 5 * 8)})
		index += 1
	if pieces.is_empty():
		push_error("No animated room parts")
		quit(1)
		return
	# One existing small part arrives last, providing a clear comic finish.
	pieces[-1]["landing"] = 1.33
	game.set_process(false)
	game.camera.size *= 1.18
	game.camera.position.y += 2.0
	for frame in range(66):
		var time := float(frame) / 30.0
		for piece: Dictionary in pieces:
			pose_piece(piece, time)
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
	print("TOY_PARTS_DEMO: PASS parts=", pieces.size(), " frames=66 final transforms exact")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	quit(0)

func pose_piece(piece: Dictionary, time: float) -> void:
	var node: Node3D = piece.node
	var final_pose: Transform3D = piece.pose
	var landing: float = piece.landing
	var start := maxf(0.0, landing - 0.72)
	node.visible = time >= start
	if time >= landing + 0.12:
		node.transform = final_pose
		return
	if time >= landing:
		var bounce := sin((time - landing) / 0.12 * PI) * 0.045
		node.transform = final_pose
		node.position.y += bounce
		return
	var t := clampf((time - start) / (landing - start), 0.0, 1.0)
	var offset: Vector3 = piece.offset
	offset.y *= 1.0 - t * t
	offset.x *= pow(1.0 - t, 2)
	offset.z *= pow(1.0 - t, 2)
	var turn := Basis(piece.axis, float(piece.angle) * pow(1.0 - t, 1.5))
	node.transform = Transform3D(turn * final_pose.basis, final_pose.origin + offset)
