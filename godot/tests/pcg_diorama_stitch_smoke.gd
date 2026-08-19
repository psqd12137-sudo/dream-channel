extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/pcg_diorama_stitch_lab.tscn") as PackedScene
	_check(packed != null, "the isolated PCG diorama scene must load")
	if packed == null:
		_finish()
		return
	var generator := packed.instantiate() as Node3D
	root.add_child(generator)
	await process_frame
	_check(generator.rooms.size() == generator.room_target, "the generator must reach its requested room count")
	_check(generator.occupancy.size() > generator.rooms.size(), "multi-cell rooms must produce more occupied cells than room instances")
	var room_sizes: Array[int] = []
	for room: Dictionary in generator.rooms:
		room_sizes.append(int(room.get("size", 0)))
	_check(1 in room_sizes and 3 in room_sizes and 5 in room_sizes, "one generation must exercise 1, 3 and 5-cell room art stitching")
	_check(int(generator.rooms[0].get("size", 0)) == 1 and int(generator.rooms[1].get("size", 0)) == 5, "the visual proof must begin with an explicit one-cell to five-cell placement")
	var proves_one_to_five := false
	for raw_record: Variant in generator.connection_edges.values():
		var record: Dictionary = raw_record
		if int(record.get("source_room", -1)) == 0 and int(record.get("target_room", -1)) == 1:
			proves_one_to_five = true
			break
	_check(proves_one_to_five, "the first one-cell and five-cell rooms must share one recorded doorway edge")
	_check(generator.connection_edges.size() == generator.rooms.size() - 1, "every later room must preserve exactly one authored attachment to the existing composition")
	_check(generator.room_visual_roots.size() == generator.rooms.size(), "every logical room must own one animated visual root regardless of footprint size")
	_check(generator.external_wall_count > 0, "the occupancy union must generate an external wall contour")
	_check(_cross_room_touch_count(generator) == generator.connection_edges.size() + generator.divider_wall_count, "every cross-room contact must be classified as doorway or visible divider")
	_check(generator.doorway_count == generator.connection_edges.size(), "every PCG attachment edge must become one visual doorway")
	_check(generator.stair_count > 0, "the connected five-cell elevation must receive an asset stair")
	_check(generator.prop_count == generator.rooms.size(), "room-level decoration must place one deterministic focal prop per room")
	_check(generator.visual_geometry_issues.is_empty(), "each canonical grid edge must spawn at most one structural segment")
	_check(generator.visual_edge_records.size() == generator.external_wall_count + generator.divider_wall_count + generator.doorway_count, "every spawned wall and doorway must have one canonical edge record")
	_check(generator.shell_geometry_is_grid_exact(), "floor, shortened wall, doorway and junction spans must resolve to exactly one grid cell")
	_check(generator.structural_edge_metadata_is_complete(), "every PCG wall and doorway must expose its canonical edge metadata to the cutaway system")
	var topology_before_cutaway: String = generator.generation_fingerprint()
	var edge_count_before_cutaway: int = generator.visual_edge_records.size()
	var connection_count_before_cutaway: int = generator.connection_edges.size()
	var cutaway: Dictionary = generator.apply_camera_cutaway(Vector2i.ZERO, Vector2.ONE)
	_check(int(cutaway["culled_walls"]) > 0, "the camera-facing dollhouse contour must cull at least one near wall")
	_check(int(cutaway["visible_walls"]) > 0, "the cutaway must retain opaque far walls for room readability")
	_check(int(cutaway["visible_doors"]) > 0 and int(cutaway["visible_doors"]) + int(cutaway["culled_doors"]) == generator.doorway_count, "cutaway presentation may hide a blocking doorway shell but must account for every PCG doorway")
	_check(generator.cutaway_markers_match_culled_edges(), "every hidden structural edge must leave one visible low sill or doorway threshold")
	_check(generator.room_state_visual_is_consistent(), "seeded PCG room state visuals must match their whole-room ownership")
	_check(generator.generation_fingerprint() == topology_before_cutaway and generator.visual_edge_records.size() == edge_count_before_cutaway and generator.connection_edges.size() == connection_count_before_cutaway, "wall cutaway must not mutate occupancy, canonical edges, or doorway topology")
	var original: String = generator.generation_fingerprint()
	generator.regenerate(generator.generation_seed)
	_check(generator.generation_fingerprint() == original, "the same seed must reproduce the same joined layout")
	generator.regenerate(generator.generation_seed + 1)
	_check(generator.generation_fingerprint() != original, "a new seed must produce a different joined layout")
	for seed_offset in range(2, 26):
		generator.regenerate(20260816 + seed_offset)
		var quality: Dictionary = generator.layout_quality_metrics()
		_check(generator.rooms.size() == generator.room_target, "seed %d must place the complete room target" % seed_offset)
		_check(generator.visual_geometry_issues.is_empty() and generator.shell_geometry_is_grid_exact(), "seed %d must preserve unique grid-exact shell geometry" % seed_offset)
		_check(int(quality["holes"]) == 0, "seed %d must not enclose an empty one-cell hole" % seed_offset)
		_check(int(quality["aspect_delta"]) <= 3, "seed %d must avoid a stretched snake composition" % seed_offset)
	generator.queue_free()
	await process_frame

	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	await process_frame
	await process_frame
	game.toggle_home_tests()
	var hud: Control = game.get_node("HUD/HUDRoot")
	_click_hud(hud, hud.HOME_TEST_DIORAMA_RECT)
	await process_frame
	_check(game.phase == "explore" and game.kenney_build_lab_mode, "the title test entry must open the formal rotating build flow with Kenney PCG art")
	_check(game.house_root.get_node_or_null("KenneyFormalComposer") != null, "the formal build flow must compose its placed room_rules data with Kenney assets")
	game.start_pcg_diorama_lab()
	await process_frame
	_check(game.phase == "lab_pcg_diorama", "the seeded composition must remain available as a secondary comparison")
	var seed_before: int = game.pcg_diorama_seed
	_click_hud(hud, hud.LAB_REROLL_RECT)
	await process_frame
	_check(game.pcg_diorama_seed == seed_before + 1, "the in-lab seed button must regenerate the whole composition")
	_click_hud(hud, hud.LAB_HAND_RECT)
	await process_frame
	_check(game.phase == "lab_hand_diorama", "the PCG lab must open the editable formal-layout simulation")
	_click_hud(hud, hud.LAB_REROLL_RECT)
	await process_frame
	_check(game.phase == "lab_pcg_diorama", "the authored layout simulation must return to the seeded PCG lab")
	_click_hud(hud, hud.LAB_SWITCH_RECT)
	await process_frame
	_check(game.phase == "lab_diorama", "the in-lab switch must return to the A/B/C asset comparison")
	game.queue_free()
	await process_frame
	_finish()


func _click_hud(hud: Control, rect: Rect2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = hud.ui_offset + rect.get_center() * hud.ui_scale
	hud._gui_input(click)


func _cross_room_touch_count(generator: Node3D) -> int:
	var count := 0
	for raw_cell: Variant in generator.occupancy.keys():
		var cell: Vector2i = raw_cell
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := cell + direction
			if generator.occupancy.has(neighbor) and int(generator.occupancy[cell]) != int(generator.occupancy[neighbor]):
				count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_PCG_DIORAMA_STITCH: PASS seeded 1-3-5 union walls doors elevation entry")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_PCG_DIORAMA_STITCH: %s" % failure)
		quit(1)
