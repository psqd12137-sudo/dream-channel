extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://channel_3d.tscn").instantiate()
	game.animation_duration_scale = 0.0
	root.add_child(game)
	await process_frame
	await process_frame
	game.go_home()
	game.start_new_run(false)
	game.choose_omen(0)

	var elite_room: Dictionary = game._find_catalog_room("hall")
	_check(int(elite_room.get("room_size", 0)) == 5, "hall must exercise the five-cell elite placement path")
	var first_frontier: Vector2i = game.room_rules.frontiers()[0]
	var legal_offers: Array[Dictionary] = game._make_build_offers(first_frontier)
	for offer: Dictionary in legal_offers:
		_check(not game.room_rules.valid_rotations(first_frontier, offer).is_empty(), "every ticket shown for a frontier must have a legal placement")
	var chosen_frontier := Vector2i.ZERO
	var chosen_rotation := -1
	for frontier: Vector2i in game.room_rules.frontiers():
		var valid: Array[int] = game.room_rules.valid_rotations(frontier, elite_room)
		if not valid.is_empty():
			chosen_frontier = frontier
			chosen_rotation = valid[0]
			break
	_check(chosen_rotation >= 0, "five-cell center-origin room must find a legal boundary-cell alignment")
	if chosen_rotation >= 0:
		game.selected_frontier = chosen_frontier
		game.build_offers.clear()
		game.build_offers.append(elite_room)
		game.selected_offer = 0
		game.offer_rotation = chosen_rotation
		game.phase = "build"
		game.build_house_world()
		_check(game.can_place_selected_offer(), "UI placement command must accept the resolved five-cell alignment")
		game.place_selected_offer()
		_check(game.room_rules.placed.has(chosen_frontier), "selected frontier must be occupied after placement")
		var instance_id := str(game.room_rules.placed[chosen_frontier].get("instance_id", ""))
		var occupied: Array[Vector2i] = []
		for raw_pos in game.room_rules.placed.keys():
			var pos: Vector2i = raw_pos
			if str(game.room_rules.placed[pos].get("instance_id", "")) == instance_id:
				occupied.append(pos)
		_check(occupied.size() == 5, "placing one elite ticket must reserve exactly five map cells")
		_check(game._find_room_instance_nodes(chosen_frontier).size() == 5, "the placement animation must address the complete five-cell room instance")

		game.enter_room(chosen_frontier)
		_check(game.phase == "room_ready", "first entry through any occupied cell must open the room event")
		game._complete_current_room()
		game.phase = "explore"
		var internal_target := chosen_frontier
		for candidate: Vector2i in occupied:
			if candidate != chosen_frontier and game._rooms_connected(chosen_frontier, candidate):
				internal_target = candidate
				break
		_check(internal_target != chosen_frontier, "elite footprint must expose an adjacent internal cell")
		if internal_target != chosen_frontier:
			game.enter_room(internal_target)
			_check(game.phase == "explore", "moving to another cell of a completed room must not retrigger its event")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHANNEL_MULTI_ROOM_BUILD: PASS boundary-anchor five-cell placement whole-room-animation single-event")
		quit(0)
	else:
		for failure: String in failures:
			push_error("CHANNEL_MULTI_ROOM_BUILD: %s" % failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
