extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://channel_3d.tscn") as PackedScene).instantiate() as Node3D
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.go_home()
	game.start_kenney_build_lab()
	await process_frame
	_check(game.phase == "explore" and game.kenney_build_lab_mode, "the lab must reuse the formal explore and build phases")
	var initial_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
	_check(initial_composer != null and bool(initial_composer.use_kaykit_room_shell), "the formal map must be rebuilt with KayKit table-model room shells")

	var elite_room: Dictionary = game._find_catalog_room("hall")
	var chosen_frontier := Vector2i.ZERO
	var chosen_rotation := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var rotations: Array[int] = game.room_rules.valid_rotations(frontier, elite_room)
		if not rotations.is_empty():
			chosen_frontier = frontier
			chosen_rotation = rotations[0]
			break
	_check(chosen_rotation >= 0, "the formal one-cell start must accept a five-cell rotated room")
	if chosen_rotation >= 0:
		game.selected_frontier = chosen_frontier
		game.build_offers.assign([elite_room])
		game.selected_offer = 0
		game.offer_rotation = chosen_rotation
		game.phase = "build"
		game.build_house_world()
		var preview := game.house_root.get_node_or_null("BuildPreview") as Node3D
		_check(preview != null and preview.find_children("KenneyPreview_*", "Node3D", true, false).size() == 5, "the live rotated preview must show the complete five-cell Kenney footprint")
		game.rotate_offer()
		await create_timer(0.08).timeout
		_check(game.offer_rotation == (chosen_rotation + 1) % 4, "the same formal rotate button must advance the table-model footprint orientation")
		game.offer_rotation = chosen_rotation
		game.build_house_world()
		_check(game.can_place_selected_offer(), "the restored valid rotation must remain placeable through formal room_rules")
		game.place_selected_offer()
		await process_frame
		var composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
		_check(game.room_rules.instance_count() == 2, "placing one five-cell ticket must create one new formal room instance")
		_check(composer != null and composer.rooms.size() == 2 and composer.occupancy.size() == 6, "the Kenney compositor must consume the placed one-plus-five formal occupancy")
		_check(composer.connection_edges.size() >= 1 and composer.doorway_count >= composer.connection_edges.size(), "formal reciprocal doors must become Kenney wall openings")
		_check(composer.room_visual_roots.size() == 2, "the five-cell room must remain one whole-building animation root")
		_check(composer.visual_geometry_issues.is_empty(), "every visible grid edge must produce at most one wall or doorway")
		_check(composer.visual_edge_records.size() == composer.external_wall_count + composer.divider_wall_count + composer.doorway_count, "the visible edge ledger must match every spawned shell segment one-for-one")
		_check(_composer_matches_formal_grid(game, composer), "the art compositor occupancy and room ownership must exactly match formal room_rules.placed")
		_check(_same_string_keys(composer.connection_edges, game._formal_connection_edge_keys()), "the art doorway set must exactly match formal reciprocal open edges")
	game.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _composer_matches_formal_grid(game: Node3D, composer: Node) -> bool:
	if composer.occupancy.size() != game.room_rules.placed.size():
		return false
	for raw_pos: Variant in game.room_rules.placed.keys():
		var pos: Vector2i = raw_pos
		if not composer.occupancy.has(pos):
			return false
		var room_index := int(composer.occupancy[pos])
		if room_index < 0 or room_index >= composer.rooms.size():
			return false
		var expected_id := str(game.room_rules.placed[pos].get("instance_id", ""))
		if str(composer.rooms[room_index].get("id", "")) != expected_id:
			return false
	return true


func _same_string_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for raw_key: Variant in a.keys():
		if not b.has(str(raw_key)):
			return false
	return true


func _finish() -> void:
	if failures.is_empty():
		print("CHANNEL_KAYKIT_FORMAL_BUILD: PASS real-frontier offer rotate preview place compose one-to-five")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_KAYKIT_FORMAL_BUILD: %s" % failure)
		quit(1)
var _smb_tail_padding := """
Kenney formal build rotation preview placement compositor regression.
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding
"""
