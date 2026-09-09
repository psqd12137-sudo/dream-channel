extends RefCounted

# Shared with the approved toy_parts_demo: keep choreography and timing identical.
const PLAYBACK_DURATION_SCALE := 1.5
const DROP_HEIGHT := 5.5
const DURATION := 2.02 * PLAYBACK_DURATION_SCALE
var camera: Camera3D
var pieces: Array[Dictionary] = []
var labels: Array[Node3D] = []
var caps: Array[Node3D] = []
var paused_tweens: Array[Tween] = []
var toy_snap_enabled := false

func prepare(modules: Array[Node3D], view: Camera3D) -> void:
	camera = view
	for module: Node3D in modules:
		var composer := module.get_parent().get_parent()
		if composer.get("cutaway_transition_tweens") != null:
			for tween: Tween in composer.cutaway_transition_tweens.values():
				if tween != null and tween.is_valid() and tween.is_running():
					tween.pause()
					paused_tweens.append(tween)
		collect(module)
	for piece: Dictionary in pieces:
		var held_time := 1.35 if piece.kind == "cap" else 0.15
		for attempt in range(200):
			pose_piece(piece, held_time)
			if lowest_screen_point(piece.node) < -48.0:
				break
			piece.offset.y += 0.5
	pose(0.0)

func collect(module: Node3D) -> void:
	for child: Node in module.get_children():
		if child is Label3D and child.visible:
			labels.append(child)
			child.visible = false
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
			"offset": Vector3(sin(index * 2.4) * 0.9, DROP_HEIGHT + float(index % 4) * 0.25, cos(index * 2.4) * 0.9),
			"axis": Vector3(0.3, 0.15, 1).normalized(), "angle": deg_to_rad(55 + index % 4 * 15) * (-1.0 if index % 2 else 1.0)})
		index += 1
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
	pieces.append({"node": cap, "pose": cap.transform, "landing": 1.60, "kind": "cap", "offset": Vector3(0.4, DROP_HEIGHT, 0), "axis": Vector3.FORWARD, "angle": 2.0})

	caps.append(cap)
	module.set_meta("assembly_part_count", pieces.size())

func pose(seconds: float) -> void:
	for piece: Dictionary in pieces:
		pose_piece(piece, seconds / PLAYBACK_DURATION_SCALE)

func finish() -> void:
	for piece: Dictionary in pieces:
		if is_instance_valid(piece.node):
			piece.node.transform = piece.pose
			piece.node.visible = true
	for label: Node3D in labels:
		if is_instance_valid(label):
			label.visible = true
	for cap: Node3D in caps:
		if is_instance_valid(cap):
			cap.free()
	for tween: Tween in paused_tweens:
		if tween != null and tween.is_valid():
			tween.play()
	pieces.clear()
	paused_tweens.clear()
	caps.clear()
	labels.clear()

func pose_piece(piece: Dictionary, time: float) -> void:
	var node: Node3D = piece.node
	if not is_instance_valid(node):
		return
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
		if toy_snap_enabled and kind == "base":
			# Gentle compression at contact, then one small settling rebound.
			var settle := sin(u * PI * 2.0) * exp(-u * 5.0)
			var compression := maxf(0.0, settle) * 0.06
			var contact_shift := 0.0
			if node is MeshInstance3D:
				contact_shift = node.get_aabb().position.y * compression * final_pose.basis.y.length()
			else:
				compression = 0.0
			node.transform = Transform3D(final_pose.basis.scaled(Vector3(1, 1.0 - compression, 1)), final_pose.origin + Vector3.UP * (contact_shift + maxf(0, -settle) * 0.018))
			return
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
	if toy_snap_enabled and kind == "base":
		# Most of the fall is unchanged; the final short descent eases into the socket.
		fall = 1.0 - pow(1.0 - t, 2.0) if t > 0.85 else (t * t * t / pow(0.85, 3.0)) * 0.9775
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

func lowest_screen_point(node: Node3D) -> float:
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	var lowest := -INF
	for child: Node in meshes:
		var mesh := child as MeshInstance3D
		var bounds := mesh.get_aabb()
		for corner in range(8):
			var point := mesh.to_global(bounds.get_endpoint(corner))
			lowest = maxf(lowest, camera.unproject_position(point).y)
	return lowest
