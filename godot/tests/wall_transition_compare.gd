extends SceneTree

# Isolated A/B art sample. Formal cutaway and saves are untouched.
const OUT := "res://../output/wall-transition-compare"
var stage: Node3D
var wall_a: Node3D
var wave_materials: Array[ShaderMaterial] = []

func _init() -> void:
	call_deferred("run")

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color, wave: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = pos
	if wave:
		var shader := Shader.new()
		shader.code = "shader_type spatial; uniform vec4 tint:source_color; uniform float amount=1.0; varying vec3 p; void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float edge=mix(-0.15,2.0,amount)+0.09*sin(p.x*8.0); if(p.y>edge)discard; ALBEDO=mix(tint.rgb,vec3(1.0,0.91,0.70),1.0-smoothstep(0.0,0.035,edge-p.y));ROUGHNESS=0.85;}"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", color)
		node.material_override = material
		wave_materials.append(material)
	else:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		node.material_override = material
	parent.add_child(node)
	return node

func room(x: float, wave: bool) -> Node3D:
	var anchor := Node3D.new()
	stage.add_child(anchor)
	anchor.position.x = x
	box(anchor, Vector3(0,-0.15,0), Vector3(3.5,0.3,2.8), Color("eac16e"))
	box(anchor, Vector3(0,0.015,0), Vector3(3.25,0.03,2.55), Color("e8849c"))
	box(anchor, Vector3(-1.6,0.8,0), Vector3(0.15,1.6,2.6), Color("b49bce"))
	box(anchor, Vector3(0,0.8,-1.25), Vector3(3.2,1.6,0.15), Color("a0d6bf"))
	# Furniture behind the foreground wall makes view clearance easy to judge.
	box(anchor, Vector3(0.25,0.5,-0.3), Vector3(1.25,0.15,0.65), Color("f7d047"))
	for dx in [-0.45,0.45]:
		box(anchor, Vector3(0.25+dx,0.25,-0.3), Vector3(0.12,0.5,0.45), Color("249d9b"))
	box(anchor, Vector3(-0.75,0.27,-0.3), Vector3(0.36,0.54,0.36), Color("f45c76"))
	var moving := Node3D.new()
	anchor.add_child(moving)
	box(moving, Vector3(0,0.83,1.15), Vector3(3.15,1.5,0.16), Color("37a99d"), wave)
	for dx in [-1.5,1.5]:
		box(moving, Vector3(dx,0.86,1.15), Vector3(0.22,1.58,0.24), Color("f2cc59"), wave)
	# A mounted graphic shares the wall's animation/mask.
	box(moving, Vector3(0,0.94,1.255), Vector3(1.0,0.65,0.055), Color("f2b37e"), wave)
	box(moving, Vector3(0,0.94,1.29), Vector3(0.62,0.38,0.025), Color("484270"), wave)
	box(anchor, Vector3(0,0.09,1.15), Vector3(3.25,0.18,0.25), Color("f2cc59"))
	return moving

func run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	stage = Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("182733")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d4e3ed")
	env.environment.ambient_light_energy = 0.55
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-25,0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.position = Vector3(0,6.5,10)
	camera.look_at(Vector3(0,0.55,0))
	wall_a = room(-2.05,false)
	room(2.05,true)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var label := Label.new()
	label.text = "A  缩入底座 · 弹出恢复                                 B  波浪擦除 · 反向印出\n\n同机位 / 同墙体 / 同时长 · 慢放 2× 便于比较"
	label.position = Vector2(160,35)
	label.add_theme_font_size_override("font_size",26)
	overlay.add_child(label)
	await process_frame
	for frame in range(105):
		var t := float(frame)/30.0
		var amount := 1.0
		var recovering := false
		if t >= 0.5 and t < 0.94:
			amount = 1.0 - smoothstep(0.5,0.94,t)
		elif t >= 0.94 and t < 1.7:
			amount = 0.0
		elif t >= 1.7 and t < 2.2:
			amount = smoothstep(1.7,2.2,t)
			recovering = true
		var wall_height := amount
		if recovering:
			var u := (t-1.7)/0.5 - 1.0
			wall_height = 1.0 + 2.7*u*u*u + 1.7*u*u
		wall_a.scale.y = maxf(0.001,wall_height)
		wall_a.position.y = -0.12*(1.0-amount)
		wall_a.visible = amount > 0.0
		for material in wave_materials:
			material.set_shader_parameter("amount",amount)
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(OUT+"/frame_%03d.png"%frame) != OK:
			quit(1)
			return
	if not is_equal_approx(wall_a.scale.y,1.0) or not is_zero_approx(wall_a.position.y):
		quit(1)
		return
	print("WALL_COMPARE: PASS 105 frames; wall and mounted graphic restore")
	quit(0)
