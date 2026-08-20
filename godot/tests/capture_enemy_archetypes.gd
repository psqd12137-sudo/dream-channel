extends SceneTree

const ARCHETYPES := ["execute", "armor", "stagger", "crush", "wire"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var file := FileAccess.open("res://data/presentation_manifest.json", FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	var variants: Dictionary = manifest.get("enemy_archetypes", {})
	var stage := Node3D.new()
	root.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("10191e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d3d0")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.45
	light.shadow_enabled = true
	stage.add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(12.0, 0.14, 3.8)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.09, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("d8c89b")
	floor.material_override = floor_material
	stage.add_child(floor)
	for index in ARCHETYPES.size():
		var archetype: String = ARCHETYPES[index]
		var config: Dictionary = variants[archetype]
		var packed := load(str(config["model_path"])) as PackedScene
		var model := packed.instantiate() as Node3D
		model.position = Vector3((float(index) - 2.0) * 2.15, float(config.get("model_y", 0.0)), 0.0)
		model.rotation.y = deg_to_rad(float(config.get("model_yaw", 0.0)))
		model.scale = Vector3.ONE * float(config.get("model_scale", 1.0))
		stage.add_child(model)
		var label := Label3D.new()
		label.text = archetype
		label.position = model.position + Vector3(0.0, 2.25, 0.0)
		label.font_size = 36
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 8
		stage.add_child(label)
		_play_idle(model)
	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(7.8, 4.6, 10.8)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.05, 0.0), Vector3.UP)
	stage.add_child(camera)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png("res://artifacts/enemy_archetypes.png")
	if error != OK:
		push_error("CAPTURE_ENEMY_ARCHETYPES: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_ENEMY_ARCHETYPES: PASS")
		quit(0)


func _play_idle(model: Node3D) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var animation_player := players[0] as AnimationPlayer
	for raw_name: StringName in animation_player.get_animation_list():
		if str(raw_name).to_lower().contains("idle"):
			animation_player.play(raw_name)
			return
