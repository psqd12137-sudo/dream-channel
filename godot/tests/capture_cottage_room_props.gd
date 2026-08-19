extends SceneTree

const ROOM_SIZES := [1, 3, 5]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/pcg_diorama_stitch_lab.tscn") as PackedScene
	var generator := packed.instantiate() as Node3D
	generator.animate_room_build = false
	generator.show_room_ids = false
	root.add_child(generator)
	await process_frame
	var rig := generator.get_node("StandaloneRig") as Node3D
	var camera := generator.get_node("StandaloneRig/Camera3D") as Camera3D
	rig.visible = true
	camera.current = true
	camera.fov = 38.0
	var title := generator.generated_root.get_node_or_null("GenerationSummary") as Node3D
	if title != null:
		title.visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/toy_show_props"))
	for room_size: int in ROOM_SIZES:
		var room_index := _find_room_index(generator, room_size)
		if room_index < 0:
			push_error("CAPTURE_COTTAGE_PROPS: no %d-cell room" % room_size)
			quit(1)
			return
		await _capture_room(generator, camera, room_index, Vector2(1, 1), "default")
		await _capture_room(generator, camera, room_index, Vector2(-1, 1), "rotated")
		await _capture_room(generator, camera, room_index, Vector2(1, 1), "glitch", true)
	print("CAPTURE_TOY_SHOW_PROPS: PASS 1/3/5 default, rotated and themed glitch")
	quit(0)


func _find_room_index(generator: Node3D, room_size: int) -> int:
	for room_index in range(generator.rooms.size()):
		if int(generator.rooms[room_index].get("size", 0)) == room_size:
			return room_index
	return -1


func _capture_room(generator: Node3D, camera: Camera3D, room_index: int, direction: Vector2, suffix: String, glitch := false) -> void:
	var room: Dictionary = generator.rooms[room_index]
	var cells: Array[Vector2i] = room["cells"]
	var target := Vector3.ZERO
	for cell: Vector2i in cells:
		target += generator._cell_world(cell, generator.layout_center)
	target /= float(cells.size())
	target.y = float(room.get("elevation", 0.0)) + 0.38
	var distance := 3.2 + sqrt(float(cells.size())) * 0.75
	var view_direction := direction.normalized()
	camera.position = target + Vector3(view_direction.x * distance, distance * 0.82, view_direction.y * distance)
	camera.look_at(target, Vector3.UP)
	generator.apply_camera_cutaway(cells[0], direction)
	generator.set_room_broadcast_glitch(room_index, glitch)
	await create_timer(0.18).timeout
	await process_frame
	var image := root.get_texture().get_image()
	var path := "res://artifacts/toy_show_props/room_%d_%s.png" % [int(room.get("size", 0)), suffix]
	if image == null or image.save_png(path) != OK:
		push_error("CAPTURE_COTTAGE_PROPS: screenshot failed %s" % path)
		quit(1)
	generator.set_room_broadcast_glitch(room_index, false)
