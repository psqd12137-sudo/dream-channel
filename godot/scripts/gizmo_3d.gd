extends Node3D
class_name Gizmo3D

## Lightweight, asset-free Unity-style gizmo used only by the room editor.
## The editor owns the transform semantics; this node only owns visuals and
## ray/AABB hit testing. It is deliberately kept outside Placements/Walls so
## it can never enter templates, overlap checks, or shadows.
##
## v5 additions:
##  - Three plane handles (XY / YZ / XZ) for plane-locked dragging.
##  - Scale is a continuous, per-axis (single-axis) handle set instead of the
##    old three-tier cube: a center uniform cube plus X/Y/Z edge handles.
##  - Hotkey note: Q/W/E/R switch tool mode; this node only reacts to `mode`.

const RED := Color("#e45b5b")
const GREEN := Color("#55c98a")
const BLUE := Color("#5b8fe4")
const GOLD := Color("#f3a51f")

## Plane handles are small translucent squares at the base of each axis pair.
const PLANE_ALPHA := 0.55
const PLANE_SIZE := 0.26

var mode := "select"
var target: Node3D = null
var _handles: Dictionary = {}


func _ready() -> void:
	set_meta("editor_gizmo", true)
	_build_visuals()
	visible = false


func _build_visuals() -> void:
	for child in get_children():
		child.free()
	_handles.clear()

	# --- Move (X/Y/Z arrows + three plane squares) ---
	var move_root := Node3D.new()
	move_root.name = "MoveArrows"
	move_root.set_meta("editor_gizmo", true)
	add_child(move_root)
	for axis in ["x", "y", "z"]:
		var arrow := _make_arrow(axis, {"x": RED, "y": GREEN, "z": BLUE}[axis])
		move_root.add_child(arrow)
		_handles["move_%s" % axis] = arrow
	# Plane handles.
	for plane in ["xy", "yz", "xz"]:
		var plane_root := _make_plane_handle(plane)
		move_root.add_child(plane_root)
		_handles["move_%s" % plane] = plane_root

	# --- Rotate (Y yaw ring) ---
	var rotate_root := Node3D.new()
	rotate_root.name = "RotateRing"
	rotate_root.set_meta("editor_gizmo", true)
	add_child(rotate_root)
	var ring := MeshInstance3D.new()
	ring.name = "YawRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 0.9
	torus.rings = 32
	torus.ring_segments = 12
	ring.material_override = _material(GOLD)
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("editor_gizmo", true)
	rotate_root.add_child(ring)
	_handles["rotate_y"] = ring

	# --- Scale (continuous: center uniform cube + X/Y/Z edge handles) ---
	var scale_root := Node3D.new()
	scale_root.name = "ScaleHandle"
	scale_root.set_meta("editor_gizmo", true)
	add_child(scale_root)
	var uniform := _make_scale_handle("scale_uniform", GOLD, Vector3(0.0, 0.55, 0.0))
	scale_root.add_child(uniform)
	_handles["scale_uniform"] = uniform
	for axis in ["x", "y", "z"]:
		var handle := _make_scale_handle("scale_%s" % axis, {"x": RED, "y": GREEN, "z": BLUE}[axis], _scale_handle_pos(axis))
		scale_root.add_child(handle)
		_handles["scale_%s" % axis] = handle


func _scale_handle_pos(axis: String) -> Vector3:
	match axis:
		"x": return Vector3(0.9, 0.0, 0.0)
		"y": return Vector3(0.0, 0.9, 0.0)
		"z": return Vector3(0.0, 0.0, 0.9)
	return Vector3.ZERO


func _make_scale_handle(handle: String, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = handle.trim_prefix("scale_").capitalize()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.16
	mesh_instance.mesh = cube
	mesh_instance.material_override = _material(color)
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("editor_gizmo", true)
	return mesh_instance


func _make_plane_handle(plane: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Plane_%s" % plane.to_upper()
	root.set_meta("editor_gizmo", true)
	root.set_meta("gizmo_handle", "move_%s" % plane)
	var mesh_instance := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(PLANE_SIZE, PLANE_SIZE)
	mesh_instance.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _plane_color(plane, PLANE_ALPHA)
	material.emission_enabled = true
	material.emission = _plane_color(plane, PLANE_ALPHA)
	material.emission_energy_multiplier = 1.2
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("editor_gizmo", true)
	root.add_child(mesh_instance)
	match plane:
		"xy": pass  # faces up (plane normal +Y), lies in XZ at y=0.13
		"yz": root.rotation.y = PI * 0.5  # faces +X
		"xz": root.rotation.x = -PI * 0.5  # faces +Z
	root.position = _plane_offset(plane)
	return root


func _plane_offset(plane: String) -> Vector3:
	match plane:
		"xy": return Vector3(0.13, 0.13, 0.0)
		"yz": return Vector3(0.0, 0.13, 0.13)
		"xz": return Vector3(0.13, 0.0, 0.13)
	return Vector3.ZERO


func _plane_color(plane: String, alpha: float) -> Color:
	match plane:
		"xy": return Color(RED.r, RED.g, RED.b, alpha)
		"yz": return Color(GREEN.r, GREEN.g, GREEN.b, alpha)
		"xz": return Color(BLUE.r, BLUE.g, BLUE.b, alpha)
	return Color(GOLD.r, GOLD.g, GOLD.b, alpha)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.5
	return material


func _make_arrow(axis: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Arrow_%s" % axis.to_upper()
	root.set_meta("editor_gizmo", true)
	root.set_meta("gizmo_handle", "move_%s" % axis)
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.045
	cylinder.bottom_radius = 0.045
	cylinder.height = 0.75
	shaft.mesh = cylinder
	shaft.material_override = _material(color)
	shaft.position = Vector3(0.0, 0.42, 0.0)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.13
	cone.height = 0.28
	head.mesh = cone
	head.material_override = _material(color)
	head.position = Vector3(0.0, 0.92, 0.0)
	root.add_child(shaft)
	root.add_child(head)
	match axis:
		"x":
			root.rotation.z = -PI * 0.5
		"z":
			root.rotation.x = PI * 0.5
	root.visible = true
	return root


func set_target(next_target: Node3D, next_mode: String) -> void:
	target = next_target
	mode = next_mode
	if target != null and is_instance_valid(target):
		global_position = target.global_position + Vector3(0.0, 0.35, 0.0)
	visible = next_mode != "select"
	_update_mode_visibility()


func clear_target() -> void:
	target = null
	visible = false


func set_mode(next_mode: String) -> void:
	mode = next_mode
	visible = target != null and is_instance_valid(target) and next_mode != "select"
	_update_mode_visibility()


func _update_mode_visibility() -> void:
	var move_root := get_node_or_null("MoveArrows")
	var rotate_root := get_node_or_null("RotateRing")
	var scale_root := get_node_or_null("ScaleHandle")
	if move_root != null:
		move_root.visible = mode == "move"
	if rotate_root != null:
		rotate_root.visible = mode == "rotate"
	if scale_root != null:
		scale_root.visible = mode == "scale"


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target) and visible:
		global_position = target.global_position + Vector3(0.0, 0.35, 0.0)


func hit_test(origin: Vector3, direction: Vector3) -> Dictionary:
	if not visible:
		return {}
	var best: Dictionary = {}
	var best_distance := INF
	for handle_name in _visible_handle_names():
		var node := _handles.get(handle_name) as Node3D
		if node == null:
			continue
		var box := _node_world_aabb(node)
		var distance := _ray_aabb_distance(origin, direction, box)
		if distance >= 0.0 and distance < best_distance:
			best_distance = distance
			best = {"handle": handle_name, "distance": distance}
	return best


func _visible_handle_names() -> Array[String]:
	match mode:
		"move":
			return ["move_x", "move_y", "move_z", "move_xy", "move_yz", "move_xz"]
		"rotate":
			return ["rotate_y"]
		"scale":
			return ["scale_uniform", "scale_x", "scale_y", "scale_z"]
	return []


func _node_world_aabb(node: Node3D) -> AABB:
	var merged := AABB()
	var found := false
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(child as MeshInstance3D)
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		merged = box if not found else merged.merge(box)
		found = true
	return merged if found else AABB()


func _ray_aabb_distance(origin: Vector3, direction: Vector3, box: AABB) -> float:
	if box.size == Vector3.ZERO:
		return -1.0
	var minimum := box.position
	var maximum := box.position + box.size
	var near_distance := 0.0
	var far_distance := INF
	for axis in 3:
		var ray_value := direction[axis]
		if absf(ray_value) < 0.000001:
			if origin[axis] < minimum[axis] or origin[axis] > maximum[axis]:
				return -1.0
			continue
		var first := (minimum[axis] - origin[axis]) / ray_value
		var second := (maximum[axis] - origin[axis]) / ray_value
		if first > second:
			var swap := first
			first = second
			second = swap
		near_distance = maxf(near_distance, first)
		far_distance = minf(far_distance, second)
		if near_distance > far_distance:
			return -1.0
	return near_distance if far_distance >= 0.0 else -1.0
