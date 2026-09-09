extends RefCounted

# Original procedural props arranged from the workshop reference, surrounding the live house.
var lab
var root: Node3D
var back: Node3D
var side: Node3D
var center := Vector3.ZERO

func group(parent: Node3D, title: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	node.position = at
	return node

func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String, roughness := 0.8) -> MeshInstance3D:
	return lab._box(parent, title, at, size, color, roughness)

func round_part(parent: Node3D, title: String, at: Vector3, radius: float, height: float, color: String, metal := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = 0.75 if metal else 0.0
	material.roughness = 0.28 if metal else 0.65
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

func ring(parent: Node3D, title: String, at: Vector3, inner: float, outer: float, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 12
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.65
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node

func build(owner_lab) -> Node3D:
	lab = owner_lab
	root = group(lab.host.house_root, "ReferenceWorkshop", Vector3.ZERO)
	var bounds := AABB(Vector3(-4, -0.8, -4), Vector3(8, 0.2, 8))
	var benches = lab.host.house_root.find_children("ToyWorkbench", "MeshInstance3D", true, false)
	if not benches.is_empty():
		bounds = benches[0].global_transform * benches[0].get_aabb()
	center = bounds.get_center()
	var top := bounds.end.y - 0.03
	var left := bounds.position.x - 1.0
	var right := bounds.end.x + 1.0
	var rear := bounds.position.z - 1.35
	var front := bounds.end.z + 0.6
	var desk := box(root, "WoodenWorkbench", Vector3(center.x, top - 0.28, center.z), Vector3(bounds.size.x + 4.6, 0.48, bounds.size.z + 4.0), "9a7451")
	var wood := Shader.new()
	wood.code = "shader_type spatial; varying vec3 p; void vertex(){p=VERTEX;} void fragment(){float g=sin(p.x*29.0+sin(p.z*0.8)*2.0)*0.007+sin(p.x*91.0+p.z)*0.003; ALBEDO=vec3(0.30,0.18,0.095)+g; ROUGHNESS=0.82;}"
	var wm := ShaderMaterial.new()
	wm.shader = wood
	desk.material_override = wm
	var mat := box(root, "CuttingMat", Vector3(center.x, top - 0.015, center.z), Vector3(bounds.size.x + 0.8, 0.06, bounds.size.z + 0.6), "386c60")
	var grid := Shader.new()
	grid.code = "shader_type spatial; varying vec3 p; void vertex(){p=VERTEX;} void fragment(){vec2 q=p.xz*2.0; vec2 d=abs(fract(q-0.5)-0.5)/max(fwidth(q),vec2(0.001)); float line=1.0-min(min(d.x,d.y),1.0); ALBEDO=mix(vec3(0.035,0.11,0.075),vec3(0.25,0.37,0.27),line*0.28); ROUGHNESS=0.95;}"
	var gm := ShaderMaterial.new()
	gm.shader = grid
	mat.material_override = gm
	var books := group(root, "BookStack", Vector3(left, top, center.z + 1.2))
	books.scale = Vector3.ONE * 1.2
	books.rotation.y = -0.17
	for i in range(3):
		var book := group(books, "Book%d" % i, Vector3(i * 0.05, i * 0.23, 0))
		book.rotation.y = i * 0.08
		box(book, "Pages", Vector3(0, 0.13, 0), Vector3(1.24, 0.17, 1.7), "d8c9a6")
		for y in [0.03, 0.23]:
			box(book, "Cover", Vector3(0, y, 0), Vector3(1.34, 0.035, 1.8), ["733d39", "293b44", "9b4038"][i])
		box(book, "Spine", Vector3(-0.65, 0.13, 0), Vector3(0.07, 0.2, 1.8), ["733d39", "293b44", "9b4038"][i])
	box(books, "BlackPen", Vector3(0.1, 0.76, 0.1), Vector3(0.07, 0.07, 1.25), "20282c", 0.4).rotation.y = 0.35
	var tape := ring(root, "TapeRoll", Vector3(left + 0.4, top + 0.17, center.z + 2.65), 0.24, 0.47, "c4ad78")
	tape.scale.y = 1.35
	var tray := group(root, "PartsTray", Vector3(right, top, center.z - 0.4))
	box(tray, "Base", Vector3(0, 0.06, 0), Vector3(1.4, 0.12, 2.1), "252d31")
	box(tray, "Insert", Vector3(0, 0.13, 0), Vector3(1.2, 0.04, 1.9), "b5b5a0")
	for sign_value in [-1, 1]:
		box(tray, "Side", Vector3(sign_value * 0.67, 0.22, 0), Vector3(0.07, 0.32, 2.1), "303940")
		box(tray, "End", Vector3(0, 0.22, sign_value * 1.0), Vector3(1.3, 0.32, 0.07), "303940")
	for i in range(8):
		round_part(tray, "Hardware%d" % i, Vector3(-0.32 + (i % 2) * 0.64, 0.26, -0.7 + (i / 2) * 0.45), 0.12, 0.2, "555f64", true)
	for i in range(3):
		var part := round_part(root, "LooseMetal%d" % i, Vector3(center.x + 0.5 + i * 0.45, top + 0.12, front + 0.3), 0.12, 0.5, "aab5b6", true)
		part.rotation.z = PI * 0.5
		ring(root, "Washer%d" % i, Vector3(center.x - 0.5 + i * 0.35, top + 0.04, front + 0.4), 0.08, 0.15, "8c989b")
	back = group(root, "WorkshopBack", Vector3(center.x, top, rear))
	box(back, "CharcoalWall", Vector3(0, 1.9, -0.2), Vector3(bounds.size.x + 4.6, 3.8, 0.18), "26343e")
	var window := group(back, "WorkshopWindow", Vector3(0, 2.05, 0))
	box(window, "BlueGlass", Vector3.ZERO, Vector3(2.8, 2.15, 0.08), "759baa", 0.32)
	for x in [-1.45, 0.0, 1.45]:
		box(window, "VerticalFrame", Vector3(x, 0, 0.09), Vector3(0.1, 2.35, 0.14), "afad96")
	for y in [-1.12, 0.0, 1.12]:
		box(window, "HorizontalFrame", Vector3(0, y, 0.09), Vector3(3.0, 0.1, 0.14), "afad96")
	box(window, "Sill", Vector3(0, -1.18, 0.2), Vector3(3.3, 0.16, 0.55), "c0af91")
	for index in range(2):
		var shelf := group(back, "ShelfLeft" if index == 0 else "ShelfRight", Vector3((-1 if index == 0 else 1) * (bounds.size.x * 0.5 + 0.35), 0, 0.22))
		for level in range(2):
			box(shelf, "ShelfBoard", Vector3(0, 1.05 + level * 1.15, 0), Vector3(2.0, 0.12, 0.65), "826348")
			for item in range(3):
				box(shelf, "SupplyBox", Vector3(-0.64 + item * 0.63, 1.38 + level * 1.15, 0), Vector3(0.51, 0.54, 0.48), ["984b42", "c3c1ab", "527e79"][(item + level) % 3])
	var clock_face := round_part(back, "WallClock", Vector3(-2.4, 3.1, 0), 0.38, 0.07, "d3c8ac")
	clock_face.rotation.x = PI * 0.5
	box(back, "ClockHand", Vector3(-2.4, 3.21, 0.07), Vector3(0.035, 0.22, 0.02), "26343e")
	box(back, "ClockMinute", Vector3(-2.29, 3.1, 0.07), Vector3(0.22, 0.025, 0.02), "26343e")
	side = group(root, "WorkshopSide", Vector3(right + 1.05, top, center.z))
	box(side, "SideWall", Vector3(0, 1.9, 0), Vector3(0.18, 3.8, bounds.size.z + 2.6), "29353f")
	var lamp := group(root, "DeskLamp", Vector3(left, top, rear + 1.1))
	round_part(lamp, "Base", Vector3(0, 0.08, 0), 0.4, 0.16, "303c3c", true)
	round_part(lamp, "Stem", Vector3(0, 0.9, 0), 0.045, 1.65, "7d8782", true)
	box(lamp, "Arm", Vector3(0.3, 1.72, 0), Vector3(0.65, 0.06, 0.06), "7d8782", 0.3)
	var shade := round_part(lamp, "Shade", Vector3(0.6, 1.58, 0), 0.34, 0.3, "526e65")
	shade.mesh.top_radius = 0.15
	var light := OmniLight3D.new()
	lamp.add_child(light)
	light.position = Vector3(0.6, 1.35, 0)
	light.light_color = Color("ffd99b")
	light.light_energy = 2.2
	light.omni_range = 4.5
	light.shadow_enabled = true
	var stool := group(root, "RedStool", Vector3(left, top - 1.0, front + 1.4))
	round_part(stool, "Seat", Vector3.ZERO, 0.5, 0.16, "9c463b")
	for x in [-0.28, 0.28]:
		for z in [-0.28, 0.28]:
			round_part(stool, "Leg", Vector3(x, -0.5, z), 0.035, 0.95, "56605d", true)
	lab = null
	return root

func update_view(camera_position: Vector3) -> void:
	# Open the enclosing set on the camera side, keeping the live toyhouse readable.
	back.visible = camera_position.z > center.z
	side.visible = camera_position.x < center.x
