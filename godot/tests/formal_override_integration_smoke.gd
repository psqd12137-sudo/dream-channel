extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/pcg_diorama_stitch_lab.tscn") as PackedScene
	assert(packed != null, "PCG scene missing")
	var generator := packed.instantiate() as Node3D
	root.add_child(generator)
	await process_frame
	assert(generator.rooms.size() > 0 and generator.room_visual_roots.size() > 0, "PCG did not build rooms")
	var room: Dictionary = generator.rooms[0]
	room["room_type"] = "living@0"
	room["revealed"] = true
	room["visited"] = true
	room["completed"] = false
	generator.rooms[0] = room
	var applied := int(generator.call("_apply_room_override", 0, "living", generator.room_visual_roots[0]))
	assert(applied == 9, "expected 5 override assets + 4 walls, got %d" % applied)
	assert(generator.room_override_is_applied("living@0"), "living override record missing")
	var root_node: Node3D = generator.room_visual_roots[0]
	assert(root_node.get_node_or_null("OverrideFurniture_living") != null, "override furniture root missing")
	assert(root_node.get_node_or_null("OverrideWalls_living") != null, "override wall root missing")
	assert(root_node.get_meta("room_override_assets", 0) == 5, "override furniture count mismatch")
	assert(root_node.get_meta("room_override_walls", 0) == 4, "override wall count mismatch")
	var override_slots: Array[Dictionary] = generator.interaction_slots_for_room_index(0)
	assert(override_slots.size() == 5, "override furniture must replace default interaction slots")
	for slot: Dictionary in override_slots:
		assert(bool(slot.get("room_override", false)), "override slot metadata missing")
		assert(bool(slot.get("aabb_in_room", false)), "override asset escaped room bounds")
		assert(not (slot.get("asset_id", "") as String).is_empty(), "override slot asset id missing")
	var couch := root_node.get_node("OverrideFurniture_living/OverrideProp_00_kk_couch") as Node3D
	assert(couch != null and couch.scale.x > 0.28, "override scale factor must enlarge furniture")
	assert(couch != null and is_equal_approx(float(couch.get_meta("override_scale_factor", 0.0)), 1.25), "override scale factor metadata missing")
	var rotated: Vector3 = generator.call("_override_local_position", Vector3(0.2, 0.0, 0.4), Vector3.ZERO, 0.0, 1)
	assert(rotated.is_equal_approx(Vector3(-0.4, 0.0, 0.2)), "room rotation must rotate override coordinates around the room center")
	# v: override walls must participate in camera cutaway — the wall facing the
	# viewer is hidden, the opposite wall stays visible.
	assert(generator.override_shell_nodes.size() == 4, "override shell nodes must be collected")
	var wall_plus_x := 0
	var wall_minus_x := 0
	for shell: Node3D in generator.override_shell_nodes:
		if shell.position.x > 0.2:
			wall_plus_x += 1
		elif shell.position.x < -0.2:
			wall_minus_x += 1
	assert(wall_plus_x > 0 and wall_minus_x > 0, "override walls must span both sides of the room centre")
	generator.cutaway_focus_room_index = 0  # focus room 0 (the living override room)
	generator.call("_apply_override_cutaway", Vector2(1, 0))  # viewer looks along +X
	var plus_x_hidden := 0
	var minus_x_hidden := 0
	for shell: Node3D in generator.override_shell_nodes:
		if not shell.visible and shell.position.x > 0.2:
			plus_x_hidden += 1
		elif not shell.visible and shell.position.x < -0.2:
			minus_x_hidden += 1
	assert(plus_x_hidden > 0, "override wall facing +X viewer must be hidden")
	assert(minus_x_hidden == 0, "opposite override wall must stay visible")
	print("CHANNEL_FORMAL_OVERRIDE_INTEGRATION: PASS living revealed assets=5 walls=4 cutaway")
	generator.queue_free()
	await process_frame
	quit(0)
