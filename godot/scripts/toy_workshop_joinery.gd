extends RefCounted

# Presentation-only geometry: the room graph and logical door edges remain untouched.
var lab_ref: WeakRef
var composer: Node3D
var base_records: Array[Dictionary] = []
var hidden_records: Array[Dictionary] = []
var added: Array[Node3D] = []
var interfaces: Array[Dictionary] = []
var enabled := false
var mat_offset := 0.0
var refined := true
var refined_hidden: Array[Dictionary] = []
var refined_floors: Array[Node3D] = []
var refined_mat_offset := 0.0
var refined_positions: Array[Dictionary] = []

func build(lab) -> void:
	lab_ref = weakref(lab)
	composer = lab.host.house_root.get_node("KenneyFormalComposer")
	var bottom := INF
	for node in lab.host.house_root.find_children("Base_*", "MeshInstance3D", true, false):
		if not node.mesh is BoxMesh:
			continue
		bottom = minf(bottom, (node.global_transform * node.get_aabb()).position.y)
		var parts := String(node.name).split("_")
		var cell := Vector2i(int(parts[1]), int(parts[2]))
		var joins := {}
		for edge in composer.visual_edge_records.values():
			if edge.kind != "door":
				continue
			var other: Vector2i
			if edge.cell == cell:
				other = edge.neighbor
			elif edge.neighbor == cell:
				other = edge.cell
			else:
				continue
			var direction: Vector2i = other - cell
			var side := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].find(direction)
			if side >= 0:
				# Opposing sides always get complementary geometry, including future neighbours.
				joins[side] = 1.0 if side in [1, 2] else -1.0
		base_records.append({"node": node, "original": node.mesh, "toy": _base_mesh(node.mesh.size, joins), "refined": _base_mesh(node.mesh.size, joins, true), "cell": cell})
		var old_floor: Node3D = node.get_parent().get_node_or_null("Floor_%d_%d" % [cell.x, cell.y])
		if old_floor != null:
			refined_hidden.append({"node": old_floor, "visible": old_floor.visible})
			var floor_mesh := MeshInstance3D.new()
			floor_mesh.name = "RefinedFloor_%d_%d" % [cell.x, cell.y]
			floor_mesh.mesh = _base_mesh(Vector3(node.mesh.size.x * 0.96, 0.012, node.mesh.size.z * 0.96), joins, true)
			node.get_parent().add_child(floor_mesh)
			floor_mesh.position = node.position + Vector3.UP * (node.mesh.size.y * 0.5 + 0.025)
			for source in old_floor.find_children("*", "MeshInstance3D", true, false):
				var material = source.get_active_material(0)
				if material is ShaderMaterial:
					floor_mesh.material_override = material.duplicate()
					floor_mesh.material_override.set_shader_parameter("pattern_to_room", floor_mesh.transform)
					break
			floor_mesh.visible = false
			refined_floors.append(floor_mesh)
	var mat: MeshInstance3D = lab.reference_root.get_node("CuttingMat")
	var mat_top: float = (mat.global_transform * mat.get_aabb()).end.y
	mat_offset = (bottom - mat_top) / lab.reference_root.get_parent().global_basis.y.length()
	var first: Dictionary = base_records[0]
	refined_mat_offset = ((first.node.global_transform * first.refined.get_aabb()).position.y - mat_top) / lab.reference_root.get_parent().global_basis.y.length()
	for marker in composer.cutaway_marker_nodes.values():
		for child in marker.get_children():
			if child is Node3D:
				refined_hidden.append({"node": child, "visible": child.visible})
	for node in lab.host.house_root.find_children("RoomStateEdge*", "MeshInstance3D", true, false):
		refined_hidden.append({"node": node, "visible": node.visible})
	for node in lab.host.house_root.find_children("BackFoot*", "MeshInstance3D", true, false):
		refined_hidden.append({"node": node, "visible": node.visible})
	for column in composer.structural_junction_nodes:
		var inward := Vector3.ZERO
		for key in column.get_meta("junction_edge_keys", []):
			var edge: Dictionary = composer.visual_edge_records.get(key, {})
			if not edge.is_empty() and not composer.occupancy.has(edge.neighbor):
				var direction: Vector2i = edge.neighbor - edge.cell
				inward -= Vector3(direction.x, 0, direction.y)
		inward = inward.clamp(-Vector3.ONE, Vector3.ONE) * 0.18
		refined_positions.append({"node": column, "original": column.position, "refined": column.position + inward})
	for node in lab.host.house_root.find_children("Frontier_*", "Node3D", false, false):
		hidden_records.append({"node": node, "visible": node.visible})
	for key in composer.structural_edge_nodes:
		var structure: Node3D = composer.structural_edge_nodes[key]
		if structure.get_meta("structure_kind") != "door":
			if not composer.occupancy.has(structure.get_meta("edge_neighbor")):
				for child in structure.get_children():
					if child is Node3D:
						refined_positions.append({"node": child, "original": child.position, "refined": child.position + Vector3(0, 0, 0.12)})
			continue
		var marker: Node3D = composer.cutaway_marker_nodes[key]
		for child in marker.get_children():
			if child is Node3D:
				hidden_records.append({"node": child, "visible": child.visible})
		var sill: MeshInstance3D = lab._box(marker, "ToyDoorThreshold", Vector3(0, 0.035, 0), Vector3(0.82, 0.09, 0.30), "d8ae61", 0.82)
		sill.visible = false
		added.append(sill)
		refined_hidden.append({"node": sill, "visible": true})
		# A single chunky open frame retracts with the existing structural parent.
		for child in structure.get_children():
			if child is Node3D:
				hidden_records.append({"node": child, "visible": child.visible})
		var frame := Node3D.new()
		frame.name = "ToyDoorFrame"
		structure.add_child(frame)
		for sign_value in [-1, 1]:
			lab._box(frame, "Post", Vector3(sign_value * 0.50, 0.48, 0), Vector3(0.23, 0.96, 0.24), "6eb4aa", 0.85)
		lab._box(frame, "Header", Vector3(0, 0.99, 0), Vector3(1.23, 0.22, 0.24), "8ac7b8", 0.85)
		frame.visible = false
		added.append(frame)
		refined_positions.append({"node": frame, "original": frame.position, "refined": Vector3(0, 0, 0.12)})
		var cell: Vector2i = structure.get_meta("edge_cell")
		var neighbor: Vector2i = structure.get_meta("edge_neighbor")
		var connected: bool = composer.occupancy.has(cell) and composer.occupancy.has(neighbor)
		interfaces.append({"key": key, "cell": cell, "neighbor": neighbor, "connected": connected, "marker": sill})
		if not connected:
			# Shallow inlaid direction cue stays physically attached to the base tab.
			var parent: Node3D = structure.get_parent()
			var cue := Node3D.new()
			cue.name = "ToyBaseSocketCue"
			parent.add_child(cue)
			cue.transform = structure.get_meta("cutaway_base_transform", marker.transform)
			cue.position.y -= 0.005
			lab._box(cue, "Inset", Vector3(0, 0, -0.015), Vector3(0.22, 0.022, 0.14), "d6b968", 0.9)
			cue.visible = false
			added.append(cue)
			refined_hidden.append({"node": cue, "visible": true})

func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value
	var lab = lab_ref.get_ref()
	for record in base_records:
		record.node.mesh = (record.refined if refined else record.toy) if enabled else record.original
	for record in hidden_records:
		record.node.visible = false if enabled else record.visible
	for node in added:
		node.visible = enabled
	for record in refined_hidden:
		if enabled and refined:
			record.node.visible = false
		elif not record.node in added and not hidden_records.any(func(r): return r.node == record.node):
			record.node.visible = record.visible
	for node in refined_floors:
		node.visible = enabled and refined
	for record in refined_positions:
		record.node.position = record.refined if enabled and refined else record.original
	lab.reference_root.position.y = (refined_mat_offset if refined else mat_offset) if enabled else 0.0

func close() -> void:
	set_enabled(false)
	for node in added:
		if is_instance_valid(node):
			node.free()
	added.clear()
	for node in refined_floors:
		if is_instance_valid(node):
			node.free()
	refined_floors.clear()

func _base_mesh(size: Vector3, joins: Dictionary, smooth_shell := false) -> ArrayMesh:
	var outline := PackedVector2Array()
	var h := Vector2(size.x, size.z) * 0.5
	var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	var radius := minf(size.x, size.z) * 0.145
	for side in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var tangent := (b - a).normalized()
		var outward := Vector2(tangent.y, -tangent.x)
		# Small round corners are modelled in the silhouette, not painted on.
		var bevel := minf(size.x * 0.085, 0.14) if smooth_shell else 0.07
		outline.append(a + tangent * bevel)
		if joins.has(side):
			var midpoint := (a + b) * 0.5
			for step in range(17):
				var angle := PI - float(step) * PI / 16.0
				outline.append(midpoint + tangent * cos(angle) * radius + outward * sin(angle) * radius * float(joins[side]))
		outline.append(b - tangent * bevel)
		var corner_center := b - tangent * bevel - outward * bevel
		for step in range(1, 5):
			var angle := atan2(outward.y, outward.x) + float(step) * PI * 0.5 / 5.0
			outline.append(corner_center + Vector2(cos(angle), sin(angle)) * bevel)
	var triangles := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2.ZERO)
	# Keep a solid foot under the female slot, so it reads as a socket rather than legs.
	var lower_height := size.y * 0.48
	var upper_bottom := -size.y * 0.5 + lower_height
	if smooth_shell:
		upper_bottom = -size.y * 0.25
	for sign_value in [-1.0, 1.0]:
		for t in range(0, triangles.size(), 3):
			for index in ([0, 1, 2] if sign_value > 0 else [2, 1, 0]):
				var p := outline[triangles[t + index]]
				if smooth_shell and sign_value < 0:
					p *= 0.985
				st.set_normal(Vector3.UP * sign_value)
				st.add_vertex(Vector3(p.x, size.y * 0.5 if sign_value > 0 else upper_bottom, p.y))
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var edge := b - a
		var normal := Vector3(edge.y, 0, -edge.x).normalized()
		var vertices := [Vector3(a.x, size.y * 0.5, a.y), Vector3(a.x, upper_bottom, a.y), Vector3(b.x, upper_bottom, b.y), Vector3(b.x, size.y * 0.5, b.y)]
		if smooth_shell:
			for index in [1, 2]:
				vertices[index].x *= 0.985
				vertices[index].z *= 0.985
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normal)
			st.add_vertex(vertices[index])
	if not smooth_shell:
		var lower: ArrayMesh = lab_ref.get_ref()._rounded_box(Vector3(size.x, lower_height, size.z), 0.025)
		st.append_from(lower, 0, Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5 + lower_height * 0.5, 0)))
	return st.commit()
