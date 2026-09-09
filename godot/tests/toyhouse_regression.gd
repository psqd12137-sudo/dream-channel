extends SceneTree

var failures: Array[String] = []
var game: Node3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	game.run_save_repository = load("res://scripts/run_save_repository.gd").new("user://toyhouse_test_only.json", game.EXE_SOURCE_ID)
	root.add_child(game)
	await process_frame
	await process_frame
	await _check_entry(0.0)
	await _check_entry(0.25)
	await _check_interrupted_drop()
	await _check_unreachable_build()
	await _check_multicell_motion()
	await _check_visited_path()
	_check_workbench()
	_check_pattern_coordinates()
	_check_material_separation()
	game.run_save_repository.clear()
	game.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("TOYHOUSE: ", "PASS" if failures.is_empty() else "FAIL %d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _start() -> void:
	game.animation_duration_scale = 0.0
	game.start_new_run(false, 2026081901)
	game.choose_omen(0)

func _check_entry(duration: float) -> void:
	_start()
	var target: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(target)
	var count_before: int = game.room_rules.instance_count()
	game.animation_duration_scale = duration
	game.place_selected_offer()
	game.place_selected_offer()
	if duration > 0.0:
		_check(game.current_room_pos != target, "actor waits while toy module lands")
		_check(not bool(game.room_rules.placed[target].revealed), "landing alone does not reveal content")
	await _wait()
	_check(game.room_rules.instance_count() == count_before + 1, "double confirmation adds exactly one module")
	_check(game.current_room_pos == target, "settled module automatically hands off to existing entry")
	_check(game.phase == "room_ready", "arrival stops at room_ready, without resolving event")
	_check(bool(game.room_rules.placed[target].get("visited", false)), "arrival records first visit")
	_check(not bool(game.room_rules.placed[target].get("completed", false)), "automatic entry does not complete room")
	var saved: Dictionary = game.run_save_repository.read()
	var saved_cell: Array = saved.get("current_room", [])
	_check(saved_cell.size() == 2 and Vector2i(int(saved_cell[0]), int(saved_cell[1])) == target, "save records the arrived location: %s versus %s" % [saved_cell, target])
	_check(str(saved.get("phase", "")) == "room_ready", "save preserves existing ready phase")

func _check_interrupted_drop() -> void:
	_start()
	var target: Vector2i = game.room_rules.frontiers()[0]
	game.begin_build(target)
	game.animation_duration_scale = 1.0
	game.place_selected_offer()
	game.go_home()
	await create_timer(1.0).timeout
	_check(game.phase == "home" and not game.animation_busy, "aborted landing never enters from home")
	game.animation_duration_scale = 0.0
	_check(game.continue_saved_run(), "committed drop snapshot remains loadable")
	_check(game.room_rules.placed.has(target), "interrupted drop preserves committed module")
	_check(game.current_room_pos != target, "load does not silently enter unvisited room")

func _check_material_separation() -> void:
	var composer: Node3D = load("res://scripts/pcg_diorama_stitch_lab.gd").new()
	var wood := MeshInstance3D.new()
	wood.mesh = BoxMesh.new()
	var felt := MeshInstance3D.new()
	felt.mesh = BoxMesh.new()
	composer._apply_handmade_prop_finish(wood, "table", "painted_wood")
	composer._apply_handmade_prop_finish(felt, "rug", "felt")
	var wood_material := wood.get_surface_override_material(0) as StandardMaterial3D
	var felt_material := felt.get_surface_override_material(0) as StandardMaterial3D
	_check(wood_material.roughness < felt_material.roughness - 0.15, "painted wood retains a softer highlight than felt")
	wood.free()
	felt.free()
	composer.free()

func _check_unreachable_build() -> void:
	_start()
	var room := {"id": "toy_test", "name": "未知模块", "doors": [true, true, true, true], "footprint": [[0, 0]], "room_size": 1}
	_check(game.room_rules.place(Vector2i.RIGHT, room, 0), "fixture creates an unvisited intermediate room")
	game.begin_build(Vector2i(2, 0))
	game.build_offers.assign([room])
	game.offer_rotation = 0
	game.selected_offer = 0
	_check(game.can_place_selected_offer(), "unreachable entrance does not alter legal placement")
	game.place_selected_offer()
	await _wait()
	_check(game.room_rules.placed.has(Vector2i(2, 0)), "unreachable module is still committed")
	_check(game.current_room_pos == Vector2i.ZERO and game.phase == "explore", "actor does not jump through unknown transit room")

func _check_pattern_coordinates() -> void:
	var composer: Node3D = load("res://scripts/pcg_diorama_stitch_lab.gd").new()
	var module := Node3D.new()
	root.add_child(module)
	module.position = Vector3(7, 2, -3)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.position = Vector3(2, 0, 0)
	floor_mesh.scale = Vector3(0.5, 1, 0.5)
	module.add_child(floor_mesh)
	composer._apply_memphis_floor_pattern(floor_mesh, {}, module)
	var material := floor_mesh.get_surface_override_material(0) as ShaderMaterial
	var mapping: Variant = material.get_shader_parameter("pattern_to_room")
	_check(mapping is Transform3D, "floor material binds mesh-to-module coordinates")
	if mapping is Transform3D:
		_check((mapping * Vector3(2, 0, 0)).is_equal_approx(Vector3(3, 0, 0)), "pattern honors child translation and imported mesh scale")
		module.position += Vector3(5, 3, 8)
		module.rotation.y = PI * 0.5
		var moved_mapping: Transform3D = material.get_shader_parameter("pattern_to_room")
		_check(moved_mapping.is_equal_approx(mapping), "module motion never slides its printed pattern")
	module.free()
	composer.free()

func _check_visited_path() -> void:
	_start()
	var room := {"id": "toy_test", "doors": [true, true, true, true], "footprint": [[0, 0]], "room_size": 1}
	game.room_rules.place(Vector2i.RIGHT, room, 0)
	game.room_rules.set_instance_flag(Vector2i.RIGHT, "visited", true)
	game.room_rules.set_instance_flag(Vector2i.RIGHT, "revealed", true)
	game.room_rules.set_instance_flag(Vector2i.RIGHT, "completed", true)
	game.begin_build(Vector2i(2, 0))
	game.build_offers.assign([room])
	game.selected_offer = 0
	game.offer_rotation = 0
	game.animation_duration_scale = 0.25
	game.place_selected_offer()
	await _wait()
	_check(game.current_room_pos == Vector2i(2, 0) and game.phase == "room_ready", "automatic entry can traverse visited intermediate rooms")

func _check_workbench() -> void:
	var composer: Node3D = game.house_root.get_node("KenneyFormalComposer")
	var surface: MeshInstance3D = composer.get_node("GeneratedMap/ToyWorkbench")
	var box: AABB = surface.get_aabb()
	for cell: Vector2i in composer.occupancy:
		var center: Vector3 = composer._cell_world(cell, composer.layout_center)
		var local_center := center - surface.position
		_check(absf(local_center.x) + composer.CELL * 0.5 <= box.size.x * 0.5 and absf(local_center.z) + composer.CELL * 0.5 <= box.size.z * 0.5, "workbench contains every cell in an asymmetric formal layout")

func _check_multicell_motion() -> void:
	_start()
	game.kenney_build_lab_mode = false
	var room := {"id": "toy_line", "doors": [true, true, true, true], "footprint": [[0, 0], [1, 0], [2, 0]], "room_size": 3}
	game.room_rules.place(Vector2i.RIGHT, room, 0)
	game.build_house_world()
	var nodes: Array[Node3D] = game._find_room_instance_nodes(Vector2i.RIGHT)
	_check(nodes.size() == 3, "legacy renderer provides all cells of one module")
	if nodes.size() == 3:
		var original_delta := nodes[1].position - nodes[0].position
		game.animation_duration_scale = 1.0
		game._animate_room_placement(Vector2i.RIGHT, "test")
		_check((nodes[1].position - nodes[0].position).is_equal_approx(nodes[0].basis * original_delta), "multi-cell module rotates and scales about one shared pivot")
		game.go_home()
	game.kenney_build_lab_mode = true

func _wait() -> void:
	var end := Time.get_ticks_msec() + 4000
	while game.animation_busy and Time.get_ticks_msec() < end:
		await process_frame
	_check(not game.animation_busy, "assembly releases input within deadline")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
