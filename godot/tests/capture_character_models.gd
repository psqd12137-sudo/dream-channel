extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("172129")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d3d0")
	environment.ambient_light_energy = 0.62
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	stage.add_child(light)
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6.5, 0.12, 3.6)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, -0.08, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("d9c99f")
	floor.material_override = floor_material
	stage.add_child(floor)
	_spawn_character(stage, "res://assets/quaternius/animated_characters/Casual_Female.gltf", Vector3(-1.35, 0.0, 0.0), 1.05)
	_spawn_character(stage, "res://assets/quaternius/animated_characters/Demon.gltf", Vector3(1.35, 0.0, 0.0), 1.15)
	var camera := Camera3D.new()
	camera.current = true
	camera.position = Vector3(4.8, 3.4, 6.6)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	stage.add_child(camera)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/temporary_character_models.png")
	if error != OK:
		push_error("CAPTURE_CHARACTER_MODELS: %s" % error_string(error))
		quit(1)
	else:
		print("CAPTURE_CHARACTER_MODELS: PASS")
		quit(0)


func _spawn_character(parent: Node3D, path: String, at: Vector3, scale_value: float) -> void:
	var packed := load(path) as PackedScene
	var character := packed.instantiate() as Node3D
	character.position = at
	character.rotation.y = 0.0
	character.scale = Vector3.ONE * scale_value
	parent.add_child(character)
	var players := character.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var animation_player := players[0] as AnimationPlayer
		for raw_name: StringName in animation_player.get_animation_list():
			if str(raw_name).to_lower() == "idle":
				var animation := animation_player.get_animation(raw_name)
				animation.loop_mode = Animation.LOOP_LINEAR
				animation_player.play(raw_name)
				break
