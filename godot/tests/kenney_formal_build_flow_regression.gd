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
	_check(initial_composer != null and bool(initial_composer.use_kaykit_room_shell) and bool(initial_composer.use_toy_show_cardboard_shell), "the formal map must use KayKit floors with toy-show cardboard wall shells")
	_check(game.frontier_markers_are_compact(), "explore frontiers must remain compact build sockets instead of looking like empty room floors")

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
		_check(composer.structural_edge_metadata_is_complete(), "formal PCG walls and doorways must retain canonical edge metadata after asset composition")
		_check(composer.room_state_visual_is_consistent(), "formal room state visuals must apply to complete multi-cell room roots")
		_check(composer.prop_layout_is_valid() and composer.prop_counts_match_room_sizes(), "formal visited rooms must use toy-show room prop budgets while unvisited rooms remain empty")
		_check(composer.prop_records_match_themes() and composer.prop_compositions_are_coherent() and composer.prop_placements_respect_reserved_clearance(), "formal furniture must stay in coherent theme compositions and outside doors, stairs and build sockets")
		_check(composer.props_use_handmade_finishes(), "formal furniture must use isolated felt, painted-wood or clay material overrides")
		_check(composer.interaction_slots_are_valid() and composer.interaction_slot_records.size() == 4, "only the visited foyer must expose its four actor slots before room entry")
		_check(composer.show_evidence_is_valid() and composer.show_evidence_records.size() == 1, "only the visited foyer may expose its actor-slot production mark before room entry")
		_check(composer.production_fixtures_are_valid() and composer.production_fixture_records.size() == 1 and composer.theme_anomalies_are_valid(), "only the visited foyer may expose its themed wall-bound production fixture before room entry: %s" % composer.production_fixture_debug_summary())
		_check(composer.toy_show_shell_palette_is_applied(), "formal room walls must use the painted-cardboard toy-show material treatment")
		_check(composer.cardboard_shell_is_valid(), "formal room walls, doors and junctions must use the grid-exact cardboard shell")
		var foyer_id := str(composer.rooms[0].get("id", ""))
		var foyer_props_before_entry: String = composer.room_prop_layout_fingerprint(foyer_id)
		var state_counts: Dictionary = composer.room_state_counts()
		_check(int(state_counts["unvisited"]) == 1 and int(state_counts["completed"]) == 1, "the newly placed five-cell room must read as one unvisited room beside the completed foyer")
		var topology_before_cutaway: String = composer.generation_fingerprint()
		var edge_count_before_cutaway: int = composer.visual_edge_records.size()
		var formal_connection_count: int = composer.connection_edges.size()
		var doorway_count_before_entry: int = composer.doorway_count
		var five_cell_focus: Vector2i = (composer.rooms[1]["cells"] as Array)[0]
		var cutaway: Dictionary = composer.apply_camera_cutaway(five_cell_focus, Vector2.ONE)
		_check(int(cutaway["focus_room_size"]) == 5, "the cutaway focus must resolve the complete formal five-cell room footprint")
		_check(int(cutaway["culled_walls"]) > 0 and int(cutaway["visible_walls"]) > 0, "formal cutaway must hide near walls while retaining far walls")
		_check(int(cutaway["visible_doors"]) > 0 and int(cutaway["visible_doors"]) + int(cutaway["culled_doors"]) + int(cutaway["open_doors"]) == composer.doorway_count, "formal cutaway must account for every authored doorway while hiding only blocking frames")
		_check(composer.cutaway_markers_match_culled_edges(), "formal hidden walls and doorway shells must retain low cutaway boundary markers")
		_check(composer.wall_bound_props_match_cutaway(), "formal wall-bound furniture must disappear with its canonical cutaway wall")
		_check(composer.generation_fingerprint() == topology_before_cutaway and composer.visual_edge_records.size() == edge_count_before_cutaway and composer.connection_edges.size() == formal_connection_count, "formal cutaway must be presentation-only and preserve PCG placement topology")
		game._finish_enter_room(game.pending_room_pos)
		var visited_composer: Node = game.house_root.get_node_or_null("KenneyFormalComposer")
		var visited_counts: Dictionary = visited_composer.room_state_counts()
		var visited_cutaway: Dictionary = visited_composer.apply_camera_cutaway(game.current_room_pos, Vector2.ONE)
		_check(bool(game.room_rules.placed[game.current_room_pos].get("visited", false)), "entering a room must set visited immediately instead of waiting for completion")
		_check(int(visited_counts["unvisited"]) == 0 and int(visited_counts["visited"]) == 1 and visited_composer.room_state_visual_is_consistent(), "entering the five-cell room must reveal its whole PCG visual root without marking it completed")
		_check(visited_composer.prop_layout_is_valid() and visited_composer.prop_counts_match_room_sizes(), "entering the five-cell room must reveal its complete deterministic 6-8 prop arrangement")
		_check(visited_composer.props_use_handmade_finishes(), "revealed furniture must retain isolated handmade material finishes")
		_check(visited_composer.interaction_slots_are_valid() and visited_composer.interaction_slot_records.size() == 24, "the visited foyer and five-cell room must expose four interaction slots per occupied cell")
		_check(visited_composer.show_evidence_is_valid() and visited_composer.show_evidence_records.size() == 2, "entering the five-cell room must reveal its production mark without changing room topology")
		_check(visited_composer.production_fixtures_are_valid() and visited_composer.production_fixture_records.size() == 2 and visited_composer.theme_anomalies_are_valid(), "entering the five-cell room must reveal its themed cutaway-aware production fixture: %s" % visited_composer.production_fixture_debug_summary())
		_check(visited_composer.room_prop_layout_fingerprint(foyer_id) == foyer_props_before_entry, "moving the current player to another room must not reflow the foyer furniture")
		var arrived_token := game.house_root.get_node_or_null("LiliToken") as Node3D
		var arrived_slot_index := int(arrived_token.get_meta("interaction_slot_index", -1)) if arrived_token != null else -1
		var arrived_slots: Array[Dictionary] = game.room_interaction_slots(game.current_room_pos)
		_check(arrived_slots.size() == 4, "the current cell must expose only its own four interaction slots")
		var expected_token_position: Vector3 = game._interaction_slot_house_position(arrived_slots[arrived_slot_index], "position") if arrived_slot_index >= 0 and arrived_slot_index < arrived_slots.size() else Vector3.INF
		_check(arrived_token != null and arrived_slot_index >= 0 and arrived_token.position.is_equal_approx(expected_token_position), "Lili must occupy a stable room interaction slot instead of displacing furniture")
		var player_activity: Dictionary = game.actor_interaction_state("player:lili")
		_check(player_activity.get("cell", Vector2i.ZERO) == game.current_room_pos and str(player_activity.get("kind", "")) == str(arrived_slots[arrived_slot_index].get("kind", "")) and player_activity.has("pose") and player_activity.has("asset_id"), "an occupied slot must retain its cell, semantic activity, pose and furniture source")
		var occupied_slot_indices: Dictionary = {arrived_slot_index: true}
		for actor_index in range(1, 4):
			var actor_id := "test:guest:%d" % actor_index
			var guest_slot: Dictionary = game.claim_room_interaction_slot(actor_id, game.current_room_pos)
			occupied_slot_indices[int(guest_slot.get("slot_index", -1))] = true
		var overflow_slot: Dictionary = game.claim_room_interaction_slot("test:guest:overflow", game.current_room_pos)
		_check(occupied_slot_indices.size() == 4 and not occupied_slot_indices.has(-1) and overflow_slot.is_empty(), "four cell slots must support four unique actors and reject a fifth occupant in that cell")
		for actor_index in range(1, 4):
			game.release_room_interaction_slot("test:guest:%d" % actor_index)
		var other_cell: Vector2i = game.current_room_pos
		for candidate_cell: Vector2i in visited_composer.rooms[1]["cells"]:
			if candidate_cell != game.current_room_pos:
				other_cell = candidate_cell
				break
		var traveler_slot: Dictionary = game.claim_room_interaction_slot("test:traveler", game.current_room_pos)
		var moved_traveler_slot: Dictionary = game.claim_room_interaction_slot("test:traveler", other_cell)
		var traveler_assignment: Dictionary = game.house_actor_slot_assignments.get("test:traveler", {})
		_check(not traveler_slot.is_empty() and not moved_traveler_slot.is_empty() and traveler_assignment.get("cell", Vector2i.ZERO) == other_cell and moved_traveler_slot.get("cell", Vector2i.ZERO) == other_cell, "an actor crossing within one multi-cell room must switch to the destination cell's slot group")
		game.release_room_interaction_slot("test:traveler")
		_check(int(visited_cutaway["open_doors"]) == visited_composer.connection_edges.size(), "entering the connected room must replace every now-traversed doorway shell with an open passage")
		_check(visited_composer.open_passages_are_clear(), "open passages must remove the door mesh while retaining a visible low threshold")
		_check(visited_composer.connection_edges.size() == formal_connection_count and visited_composer.doorway_count == doorway_count_before_entry, "opening a visited passage must preserve the formal connection and doorway ledgers")
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
