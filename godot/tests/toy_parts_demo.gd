extends SceneTree

# Isolated visual prototype. No changes to the formal placement flow.
const OUT := "res://../output/toy-parts-cartoon"
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
	var index := 0
	for child: Node in module.get_children():
		if not child is Node3D or not child.visible or child is Label3D:
			continue
		var name_lower := String(child.name).to_lower()
		var kind := "wall"
		var landing := 0.82 + float(index % 5) * 0.055
		if "base" in name_lower:
			kind = "base"
			landing = 0.53 + float(index % 3) * 0.025
		elif "floor" in name_lower:
			kind = "base"
			landing = 0.63 + float(index % 3) * 0.025
		elif "prop" in name_lower or "furniture" in name_lower:
			kind = "prop"
			landing = 1.10 + float(index % 4) * 0.035
		pieces.append({"node": child, "pose": child.transform, "landing": landing, "kind": kind,
			"offset": Vector3(sin(index * 2.4) * 0.9, 2.4 + float(index % 4) * 0.25, cos(index * 2.4) * 0.9),
			"axis": Vector3(0.3, 0.15, 1).normalized(), "angle": deg_to_rad(55 + index % 4 * 15) * (-1.0 if index % 2 else 1.0)})
		index += 1
	if pieces.is_empty():
		push_error("No animated room parts")
		quit(1)
		return
	# A deliberately oversized toy cap makes the delayed punchline readable.
	var cap := MeshInstance3D.new()
	cap.name = "LateToyCap"
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.16
	cap_mesh.height = 0.32
	cap.mesh = cap_mesh
	var cap_material := StandardMaterial3D.new()
	cap_material.albedo_color = Color("ff388a")
	cap.material_override = cap_material
	var cap_anchor := Vector3.ZERO
	for mesh_node: Node in module.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if not mesh_instance.is_visible_in_tree():
			continue
		var bounds := mesh_instance.get_aabb()
		var local_top := bounds.get_center() + Vector3.UP * bounds.size.y * 0.5
		var top := module.to_local(mesh_instance.to_global(local_top))
		if top.y > cap_anchor.y:
			cap_anchor = top
	module.add_child(cap)
	cap.position = cap_anchor + Vector3.UP * 0.16
	pieces.append({"node": cap, "pose": cap.transform, "landing": 1.60, "kind": "cap", "offset": Vector3(0.4, 3, 0), "axis": Vector3.FORWARD, "angle": 2.0})
	game.set_process(false)
	game.camera.size *= 1.18
	game.camera.position.y += 2.0
	for frame in range(78):
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
	print("TOY_PARTS_DEMO: PASS parts=", pieces.size(), " frames=78 final transforms exact")
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	quit(0)

func pose_piece(piece: Dictionary, time: float) -> void:
	var node: Node3D = piece.node
	var final_pose: Transform3D = piece.pose
	var landing: float = piece.landing
	var kind: String = piece.kind
	var start := 1.20 if kind == "cap" else 0.0
	node.visible = time >= start
	if time >= landing + 0.42:
		node.transform = final_pose
		return
	if time >= landing:
		var u := (time - landing) / 0.42
		var squash := sin(u * PI * 4.0 + PI * 0.5) * exp(-u * 5.0)
		var strength := 0.36 if kind == "base" else 0.24
		var stretch := Vector3(1.0 + squash * strength * 0.55, 1.0 - squash * strength, 1.0 + squash * strength * 0.55)
		var wobble := sin(u * PI * 5.0) * exp(-u * 4.0) * (0.32 if kind == "wall" else 0.12)
		var bounce := absf(sin(u * PI * 2.0)) * (1.0 - u) * (0.65 if kind == "cap" else 0.16)
		node.transform = Transform3D(Basis(Vector3.FORWARD, wobble).scaled(stretch) * final_pose.basis, final_pose.origin + Vector3.UP * bounce)
		return
	# All parts burst into a held, crooked pose, then snap down in rhythmic groups.
	var fall_start := landing - 0.20
	var t := clampf((time - fall_start) / 0.20, 0.0, 1.0)
	var fall := t * t * t
	var offset: Vector3 = piece.offset
	offset *= 1.0 - fall
	if time < start + 0.12:
		offset.y += (1.0 - clampf((time - start) / 0.12, 0, 1)) * 2.0
	var angle := float(piece.angle) * (1.0 - fall)
	if kind == "prop":
		angle += TAU * (1.0 - t)
	var turn := Basis(piece.axis, angle)
	var stretch := Vector3(1.0 - 0.16 * sin(t * PI), 1.0 + 0.40 * sin(t * PI), 1.0 - 0.16 * sin(t * PI))
	node.transform = Transform3D(turn.scaled(stretch) * final_pose.basis, final_pose.origin + offset)
